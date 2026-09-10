import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:petwalk/services/geo.dart';

/// 서울시청 앞. 테스트 경로의 출발점.
const double kBaseLat = 37.5665;
const double kBaseLng = 126.9780;

const double _mPerDegLat = 111320;

double _mPerDegLng(double lat) => _mPerDegLat * cos(lat * pi / 180);

/// 시뮬레이션한 산책 하나.
class SimulatedWalk {
  const SimulatedWalk(this.positions, this.trueDistanceM);

  final List<Position> positions;

  /// 노이즈를 뺀 실제 경로 길이. 필터가 얼마나 정확한지 재는 기준이 된다.
  final double trueDistanceM;
}

/// 북쪽으로 걷다가 동쪽으로 꺾는 L자 경로를 만든다.
///
/// [jitterM] 으로 GPS 오차를 섞는다. 이게 있어야 필터를 실제로 시험하는
/// 셈이 된다. 오차 없는 좌표만 넣으면 필터가 하는 일이 없다.
// 기본값은 약 1.2km, 13분짜리 산책이다. 실제 강아지 산책 길이에 맞췄다.
// 코스 매칭이 요구하는 최소 geohash 셀 수(4개)를 넘기려면 이 정도는 돼야 한다.
// 셀 하나가 약 150m 라 수백 미터짜리 경로는 한두 셀에 다 들어가 버린다.
SimulatedWalk simulateWalk({
  int points = 200,
  double stepM = 6,
  int turnAt = 100,
  int intervalSec = 4,
  double accuracy = 8,
  double jitterM = 3,
  double speedMps = 1.4,
  int seed = 1,
  DateTime? startedAt,
}) {
  final rnd = Random(seed);
  final start = startedAt ?? DateTime(2026, 9, 10, 9);
  final result = <Position>[];

  double? prevLat, prevLng;
  var trueDistance = 0.0;

  for (var i = 0; i < points; i++) {
    final north = i < turnAt ? i * stepM : turnAt * stepM;
    final east = i < turnAt ? 0.0 : (i - turnAt) * stepM;

    // 노이즈를 뺀 참값으로 실제 경로 길이를 누적한다.
    final trueLat = kBaseLat + north / _mPerDegLat;
    final trueLng = kBaseLng + east / _mPerDegLng(kBaseLat);
    if (prevLat != null) {
      trueDistance += haversineM(prevLat, prevLng!, trueLat, trueLng);
    }
    prevLat = trueLat;
    prevLng = trueLng;

    final jLat = (rnd.nextDouble() - 0.5) * 2 * jitterM;
    final jLng = (rnd.nextDouble() - 0.5) * 2 * jitterM;

    result.add(Position(
      latitude: kBaseLat + (north + jLat) / _mPerDegLat,
      longitude: kBaseLng + (east + jLng) / _mPerDegLng(kBaseLat),
      timestamp: start.add(Duration(seconds: i * intervalSec)),
      accuracy: accuracy,
      altitude: 30,
      altitudeAccuracy: 5,
      heading: i < turnAt ? 0 : 90,
      headingAccuracy: 5,
      speed: speedMps,
      speedAccuracy: 0.5,
    ));
  }

  return SimulatedWalk(result, trueDistance);
}

/// 제자리에 서 있는 상황. 좌표만 흔들리고 실제 이동은 0이다.
SimulatedWalk simulateStandingStill({
  int points = 30,
  int intervalSec = 2,
  double accuracy = 8,
  double jitterM = 8,
  int seed = 2,
  DateTime? startedAt,
}) {
  final rnd = Random(seed);
  final start = startedAt ?? DateTime(2026, 9, 10, 9);

  final result = <Position>[
    for (var i = 0; i < points; i++)
      Position(
        latitude: kBaseLat + ((rnd.nextDouble() - 0.5) * 2 * jitterM) / _mPerDegLat,
        longitude:
            kBaseLng + ((rnd.nextDouble() - 0.5) * 2 * jitterM) / _mPerDegLng(kBaseLat),
        timestamp: start.add(Duration(seconds: i * intervalSec)),
        accuracy: accuracy,
        altitude: 30,
        altitudeAccuracy: 5,
        heading: 0,
        headingAccuracy: 5,
        speed: 0.05,
        speedAccuracy: 0.5,
      ),
  ];

  return SimulatedWalk(result, 0);
}

/// 좌표를 남/북으로 밀어 다른 장소의 산책으로 만든다.
/// 코스 매칭이 서로 다른 길을 구분하는지 볼 때 쓴다.
Position shiftPosition(Position p, double northM) => Position(
      latitude: p.latitude + northM / _mPerDegLat,
      longitude: p.longitude,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      altitude: p.altitude,
      altitudeAccuracy: p.altitudeAccuracy,
      heading: p.heading,
      headingAccuracy: p.headingAccuracy,
      speed: p.speed,
      speedAccuracy: p.speedAccuracy,
    );
