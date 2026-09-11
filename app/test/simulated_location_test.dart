import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/geo.dart';
import 'package:petwalk/services/location_service.dart';
import 'package:petwalk/services/simulated_location_service.dart';
import 'package:petwalk/services/track_filter.dart';
import 'package:petwalk/services/walk_recorder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_location_service.dart';

void main() {
  // 산책을 시작하면 DB 에 기록이 들어간다. 메모리 DB 로 받아 둔다.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDb.resetForTesting();
    AppDb.pathOverride = inMemoryDatabasePath;
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  tearDown(() async => AppDb.resetForTesting());

  group('가짜 GPS', () {
    test('권한을 묻지 않고 바로 준비된다', () async {
      // 웹에서 위치 권한 팝업이 뜨면 개발용 도구로서 쓸모가 떨어진다.
      final svc = SimulatedLocationService();
      expect(await svc.ensurePermission(), LocationReadiness.ready);
      await svc.dispose();
    });

    test('시간이 지나면 좌표가 앞으로 나아간다', () async {
      final svc = SimulatedLocationService(
        tick: const Duration(milliseconds: 10),
        jitterM: 0,
      );

      final points = await svc.positionStream().take(5).toList();
      await svc.dispose();

      expect(points, hasLength(5));

      // 노이즈를 뺐으므로 북쪽으로 단조 증가해야 한다.
      for (var i = 1; i < points.length; i++) {
        expect(points[i].latitude, greaterThan(points[i - 1].latitude));
      }

      final moved = haversineM(
        points.first.latitude,
        points.first.longitude,
        points.last.latitude,
        points.last.longitude,
      );
      expect(moved, greaterThan(0));
    });

    test('재개해도 출발점으로 돌아가지 않는다', () async {
      // 일시정지 후 재개하면 레코더가 구독을 다시 건다. 그때 좌표가
      // 처음으로 돌아가면 경로가 출발점으로 순간이동한다.
      final svc = SimulatedLocationService(
        tick: const Duration(milliseconds: 10),
        jitterM: 0,
      );

      final first = await svc.positionStream().take(3).toList();
      final second = await svc.positionStream().take(3).toList();
      await svc.dispose();

      expect(second.first.latitude, greaterThan(first.last.latitude));
    });

    test('꺾은 뒤에는 동쪽으로 간다', () async {
      // 직선 하나짜리 경로는 지도에서 확인하는 의미가 적다.
      final svc = SimulatedLocationService(
        tick: const Duration(milliseconds: 5),
        turnAfter: 3,
        jitterM: 0,
      );

      final points = await svc.positionStream().take(7).toList();
      await svc.dispose();

      // i == turnAfter 부터 북쪽이 멈추고 동쪽으로 간다.
      final atTurn = points[3];
      final afterTurn = points[6];
      expect(afterTurn.latitude, closeTo(atTurn.latitude, 1e-9));
      expect(afterTurn.longitude, greaterThan(atTurn.longitude));
    });

    test('기본 속도가 GPS 필터를 통과한다', () async {
      // 처음에 6m/0.5초(12 m/s)로 만들었다가 필터가 전부 "튄 좌표"로
      // 버려서 거리가 0 에서 움직이지 않았다. 시뮬레이터를 빠르게 만들고
      // 싶은 유혹이 계속 있을 자리라 못을 박아 둔다.
      final svc = SimulatedLocationService();
      final impliedSpeed =
          svc.stepM / (svc.tick.inMilliseconds / 1000);

      expect(impliedSpeed, lessThan(GpsFilter.maxSpeedMps),
          reason: '이 속도로는 좌표가 전부 버려져 거리가 쌓이지 않는다');
      expect(impliedSpeed, greaterThan(1.0),
          reason: '너무 느리면 확인하는 데 시간이 오래 걸린다');
    });

    test('실제로 필터를 통과해 거리가 쌓인다', () async {
      final svc = SimulatedLocationService(
        tick: const Duration(milliseconds: 5),
      );
      final points = await svc.positionStream().take(40).toList();
      await svc.dispose();

      // 시뮬레이터는 빠르게 돌리되, 필터에는 좌표 사이 시간차가 실제
      // 간격(1초)으로 보이도록 맞춰 준다.
      final filter = GpsFilter();
      final base = DateTime(2026, 1, 1);
      var accepted = 0;
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final out = filter.add(RawFix(
          lat: p.latitude,
          lng: p.longitude,
          accuracy: p.accuracy,
          ts: base.add(Duration(seconds: i)),
          alt: p.altitude,
          deviceSpeedMps: p.speed,
        ));
        if (out != null) accepted++;
      }

      // 준비 구간(warmupSkip)을 빼고도 대부분 통과해야 한다.
      expect(accepted, greaterThan(points.length ~/ 2));
    });

    test('멈추면 더 내보내지 않는다', () async {
      final svc = SimulatedLocationService(
        tick: const Duration(milliseconds: 10),
      );

      final seen = <double>[];
      final sub = svc.positionStream().listen((p) => seen.add(p.latitude));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      svc.stop();
      final countAtStop = seen.length;

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(seen.length, countAtStop);

      await sub.cancel();
      await svc.dispose();
    });
  });

  group('레코더의 위치 출처 교체', () {
    test('멈춰 있으면 바꿀 수 있다', () {
      final recorder = WalkRecorder(location: FakeLocationService());
      final sim = SimulatedLocationService();

      recorder.location = sim;
      expect(recorder.location, same(sim));
    });

    test('바뀌면 화면에 알린다', () {
      // 화면이 "지금 가짜 GPS 인지"를 표시하므로 알림이 없으면 버튼이
      // 눌러도 그대로인 것처럼 보인다.
      final recorder = WalkRecorder(location: FakeLocationService());
      var notified = 0;
      recorder.addListener(() => notified++);

      recorder.location = SimulatedLocationService();
      expect(notified, 1);
    });

    test('같은 것으로 다시 바꾸면 알리지 않는다', () {
      final sim = SimulatedLocationService();
      final recorder = WalkRecorder(location: sim);
      var notified = 0;
      recorder.addListener(() => notified++);

      recorder.location = sim;
      expect(notified, 0);
    });

    test('기록 중에는 바꿀 수 없다', () async {
      // 중간에 출처가 바뀌면 두 스트림의 좌표가 섞여 경로가 튄다.
      final recorder = WalkRecorder(location: FakeLocationService());
      await recorder.start();

      expect(
        () => recorder.location = SimulatedLocationService(),
        throwsStateError,
      );
    });
  });
}
