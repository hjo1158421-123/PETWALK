import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:petwalk/models/walk.dart';
import 'package:petwalk/services/db.dart';
import 'package:petwalk/services/walk_recorder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_location_service.dart';

/// 경과 시간을 벽시계로 계산하는지 검증한다.
///
/// 예전에는 `Timer.periodic` 으로 1초씩 셌다. 화면이 꺼지거나 탭이
/// 백그라운드로 가면 타이머는 throttle 되어 멈추는데 GPS 는 계속 들어와서
/// `movingSec` 이 전체 시간을 앞질러 버렸고, `Walk.sniffRatio`(멈춰서 냄새
/// 맡은 비율)가 음수로 나오는 버그로 이어졌다.
///
/// `WalkRecorder(now: ...)` 로 가짜 시계를 주입해서, 실제로 몇 초씩
/// 기다리지 않고도 "타이머가 멈춰도 시간은 맞다"를 확인한다.
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

  tearDown(() async => AppDb.resetForTesting());

  test('일시정지한 시간은 경과 시간에서 빠진다', () async {
    var now = DateTime(2026, 1, 1, 9, 0, 0);
    final recorder = WalkRecorder(
      location: FakeLocationService(),
      now: () => now,
    );

    await recorder.start();
    now = now.add(const Duration(seconds: 30));
    expect(recorder.elapsedSec, 30);

    recorder.pause();
    // 일시정지 중 100초가 지나도 경과 시간에 반영되면 안 된다.
    now = now.add(const Duration(seconds: 100));
    expect(recorder.elapsedSec, 30, reason: '일시정지 중에는 시간이 흐르면 안 된다');

    recorder.resume();
    now = now.add(const Duration(seconds: 20));
    expect(recorder.elapsedSec, 50, reason: '30초 + 20초, 일시정지한 100초는 빠진다');
  });

  test('타이머 없이도 경과 시간이 맞다 (throttle 시나리오)', () async {
    // 화면이 꺼져 Timer.periodic 이 멈춘 상황을 흉내낸다.
    // elapsedSec 을 한 번도 "틱"하지 않고 시계만 옮긴다.
    var now = DateTime(2026, 1, 1, 9, 0, 0);
    final recorder = WalkRecorder(
      location: FakeLocationService(),
      now: () => now,
    );

    await recorder.start();
    now = now.add(const Duration(minutes: 5));

    expect(recorder.elapsedSec, 300, reason: '타이머를 한 번도 안 돌려도 벽시계로 맞아야 한다');
  });

  test('저장된 산책의 totalSec 은 일시정지를 뺀 값이다', () async {
    var now = DateTime(2026, 1, 1, 9, 0, 0);
    final location = FakeLocationService();
    final recorder = WalkRecorder(location: location, now: () => now);

    await recorder.start();

    // GpsFilter 는 처음 3개 픽스를 워밍업으로 버리고(warmupSkip), 그 다음
    // 유효 픽스 하나는 거리 기준점(anchor)으로만 쓰인다. 최소 거리(30m)도
    // 채워야 저장되므로 10개를 흘려 넉넉히(약 60m) 채운다.
    const points = 10;
    for (var i = 0; i < points; i++) {
      location.emit(_posAt(37.5665 + i * 0.00009, 126.9780, now));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 4));
    }

    recorder.pause();
    now = now.add(const Duration(seconds: 999)); // 오래 쉼
    recorder.resume();
    now = now.add(const Duration(seconds: 10));

    final walk = await recorder.stop();
    recorder.dispose();
    await location.close();

    expect(walk, isNotNull);
    // points * 4초 = 40초 이동 구간 + 10초, 999초 일시정지는 totalSec 에서 빠진다.
    expect(walk!.totalSec, points * 4 + 10);
  });

  test('movingSec 이 totalSec 을 넘어도 sniffRatio 는 음수가 아니다', () {
    // 실제로는 벽시계 계산 덕에 거의 안 생기지만, GPS 타임스탬프와
    // 벽시계는 여전히 서로 다른 시계라 반올림이 겹치면 생길 수 있다.
    // Walk 모델 자체가 방어하는지 직접 확인한다. 예전 버그의 실제 관측값
    // (총 97초, 이동 191초)을 그대로 재현한다.
    final walk = Walk(
      startedAt: DateTime(2026, 1, 1),
      totalSec: 97,
      movingSec: 191,
    );

    expect(walk.sniffRatio, 0.0);
    expect(walk.sniffRatio, greaterThanOrEqualTo(0.0));
  });

  test('정상적인 값에서는 sniffRatio 가 그대로 계산된다', () {
    final walk = Walk(
      startedAt: DateTime(2026, 1, 1),
      totalSec: 100,
      movingSec: 60,
    );

    expect(walk.sniffRatio, closeTo(0.4, 1e-9));
  });
}

Position _posAt(double lat, double lng, DateTime ts) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: ts,
      accuracy: 8,
      altitude: 30,
      altitudeAccuracy: 5,
      heading: 0,
      headingAccuracy: 5,
      speed: 1.4,
      speedAccuracy: 0.5,
    );
