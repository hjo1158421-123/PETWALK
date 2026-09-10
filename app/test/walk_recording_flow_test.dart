import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/models/walk.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/location_service.dart';
import 'package:petwalk/services/walk_recorder.dart';
import 'package:petwalk/services/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_location_service.dart';
import 'support/walk_simulator.dart';

/// 산책 기록의 전 과정을 실제 부품으로 돌려 보는 통합 테스트.
///
/// 가짜 GPS 좌표를 흘려 넣고 → 필터를 거쳐 → DB에 저장되고 → 코스로 묶이는
/// 데까지, 손으로 클릭해 확인하던 것을 그대로 자동화했다.
/// 화면은 건드리지 않는다. 화면까지 포함한 검증은 integration_test/ 쪽에 있다.
///
/// 기기나 에뮬레이터 없이 `flutter test` 로 돌아간다.
/// DB는 메모리 DB라 실제 저장소를 건드리지 않는다.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDb.resetForTesting();
    AppDb.pathOverride = inMemoryDatabasePath;
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await AppDb.resetForTesting();
  });

  test('좌표를 받으면 거리가 쌓이고, 종료하면 기록이 저장된다', () async {
    final repo = WalkRepository();
    final walk = simulateWalk();

    expect(await repo.listWalks(), isEmpty);

    final saved = await _record(walk);

    expect(saved, isNotNull, reason: '충분히 걸었으면 기록이 저장돼야 한다');
    expect(saved!.endedAt, isNotNull);
    expect(
      saved.distanceM,
      closeTo(walk.trueDistanceM, walk.trueDistanceM * 0.2),
      reason: 'GPS 오차를 섞어도 실제 경로 길이의 20% 안에 들어와야 한다',
    );

    final stored = await repo.listWalks();
    expect(stored, hasLength(1));
    expect(stored.single.id, saved.id);

    final points = await repo.pointsFor(saved.id!);
    expect(points.length, greaterThan(10), reason: '좌표가 함께 저장돼야 한다');
    expect(points.first.ts.isBefore(points.last.ts), isTrue);
  });

  test('제자리에 서 있기만 하면 기록으로 남기지 않는다', () async {
    final repo = WalkRepository();

    final saved = await _record(simulateStandingStill());

    expect(saved, isNull, reason: 'GPS 드리프트만으로는 산책이 되면 안 된다');
    expect(await repo.listWalks(), isEmpty);
    expect(await repo.listCourses(), isEmpty);
  });

  test('같은 길을 두 번 걸으면 하나의 코스로 묶인다', () async {
    final repo = WalkRepository();

    // 같은 길이라도 매번 똑같은 좌표가 찍히지는 않는다. 시드를 바꿔
    // 오차 패턴을 다르게 준다.
    final first = await _record(simulateWalk(seed: 1));
    final second = await _record(simulateWalk(seed: 7));

    expect(first, isNotNull);
    expect(second, isNotNull);

    final courses = await repo.listCourses();
    expect(courses, hasLength(1), reason: '같은 길이면 코스는 하나여야 한다');
    expect(courses.single.walkCount, 2);

    final walks = await repo.listWalks();
    expect(walks, hasLength(2));
    expect(walks.every((w) => w.courseId == courses.single.id), isTrue);
  });

  test('다른 길을 걸으면 별도 코스가 된다', () async {
    final repo = WalkRepository();

    await _record(simulateWalk(seed: 1));
    // 출발점을 1km 남쪽으로 옮기면 geohash 셀이 전혀 겹치지 않는다.
    await _record(simulateWalk(seed: 1, startedAt: DateTime(2026, 9, 10, 18)),
        latOffsetM: -1000);

    expect(await repo.listCourses(), hasLength(2));
  });
}

/// 산책 한 번을 통째로 돌린다. 시작 → 좌표 주입 → 종료.
Future<Walk?> _record(SimulatedWalk walk, {double latOffsetM = 0}) async {
  final location = FakeLocationService();
  final recorder = WalkRecorder(location: location);

  final readiness = await recorder.start();
  expect(readiness, LocationReadiness.ready);

  for (final p in walk.positions) {
    location.emit(latOffsetM == 0 ? p : shiftPosition(p, latOffsetM));
    // 스트림 리스너가 돌 틈을 준다
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));

  final saved = await recorder.stop();
  recorder.dispose();
  await location.close();
  return saved;
}
