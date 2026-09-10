import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petwalk/main.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/walk_recorder.dart';
import 'package:petwalk/services/walk_repository.dart';
import 'package:petwalk/widgets/route_map.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/fake_location_service.dart';
import '../test/support/walk_simulator.dart';

/// 화면까지 포함한 종단 테스트. 실제로 버튼을 누르고 화면 전환을 확인한다.
///
/// 손으로 클릭해서 확인하던 것을 그대로 자동화한 것이다:
/// 산책 시작 → 좌표 수신 → 거리 표시 → 종료 → 완료 화면 → 이력에 남기.
///
/// 이건 기기나 에뮬레이터가 있어야 돌아간다. GPS 만 가짜로 바꾸고
/// 나머지는 전부 실제 앱 그대로다.
///
/// 실행:
///   flutter test integration_test -d <기기ID>
///
/// 기기 없이 돌릴 수 있는 서비스 계층 테스트는
/// test/walk_recording_flow_test.dart 에 있다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 기기에서도 타일을 받아오면 프레임이 계속 돌아 pump 가 끝나지 않는다.
    RouteMap.tilesEnabled = false;
  });

  setUp(() async {
    await AppDb.resetForTesting();
    // 기기의 실제 DB 를 쓰되 테스트 전용 파일로 분리한다.
    AppDb.pathOverride = 'petwalk_integration_test.db';
    await databaseFactory.deleteDatabase(AppDb.pathOverride!);
  });

  tearDown(() async {
    await AppDb.resetForTesting();
  });

  testWidgets('산책 시작 → 기록 → 종료 → 이력에 남는다', (tester) async {
    final location = FakeLocationService();
    final repo = WalkRepository();
    final walk = simulateWalk();

    await tester.pumpWidget(
      PetWalkApp(recorderFactory: () => WalkRecorder(location: location)),
    );
    await tester.pumpAndSettle();

    // --- 시작 전 ---
    expect(find.text('산책 시작'), findsOneWidget);

    await tester.tap(find.text('산책 시작'));
    await tester.pumpAndSettle();

    // --- 기록 중 화면으로 바뀐다 ---
    expect(find.text('종료'), findsOneWidget);
    expect(find.text('일시정지'), findsOneWidget);

    // --- 좌표 주입 ---
    for (final p in walk.positions) {
      location.emit(p);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.pumpAndSettle();

    // --- 종료하면 완료 화면으로 ---
    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();

    expect(find.text('산책이 기록되었어요'), findsOneWidget);

    // --- DB 에 남았는지 ---
    final saved = await repo.listWalks();
    expect(saved, hasLength(1));
    expect(
      saved.single.distanceM,
      closeTo(walk.trueDistanceM, walk.trueDistanceM * 0.2),
    );

    await location.close();
  });

  testWidgets('이동 거리가 짧으면 저장하지 않고 안내한다', (tester) async {
    final location = FakeLocationService();
    final repo = WalkRepository();

    await tester.pumpWidget(
      PetWalkApp(recorderFactory: () => WalkRecorder(location: location)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('산책 시작'));
    await tester.pumpAndSettle();

    for (final p in simulateStandingStill().positions) {
      location.emit(p);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();

    expect(find.text('이동 거리가 너무 짧아 기록하지 않았어요.'), findsOneWidget);
    expect(await repo.listWalks(), isEmpty);

    await location.close();
  });
}
