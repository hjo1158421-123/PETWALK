import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/services/geo.dart';
import 'package:petwalk/services/track_filter.dart';

const _baseLat = 37.5665;
const _baseLng = 126.9780;
const _mPerDegLat = 111320.0;

double _latOffset(double meters) => meters / _mPerDegLat;
double _lngOffset(double meters) =>
    meters / (_mPerDegLat * cos(_baseLat * pi / 180));

void main() {
  group('GpsFilter', () {
    test('제자리에 서 있으면 GPS가 흔들려도 거리가 쌓이지 않는다', () {
      // 2분간 정지. 좌표는 ±8m로 흔들리고 칩 속도는 0에 가깝다.
      final rnd = Random(42);
      final filter = GpsFilter();
      var start = DateTime(2026, 9, 10, 9);

      var filtered = 0.0;
      var raw = 0.0;
      double? prevLat, prevLng;

      for (var i = 0; i < 60; i++) {
        final lat = _baseLat + _latOffset((rnd.nextDouble() - 0.5) * 16);
        final lng = _baseLng + _lngOffset((rnd.nextDouble() - 0.5) * 16);
        final ts = start.add(Duration(seconds: i * 2));

        if (prevLat != null) {
          raw += haversineM(prevLat, prevLng!, lat, lng);
        }
        prevLat = lat;
        prevLng = lng;

        final fix = filter.add(RawFix(
          lat: lat,
          lng: lng,
          accuracy: 8,
          ts: ts,
          deviceSpeedMps: 0.05,
        ));
        filtered += fix?.deltaM ?? 0;
      }

      // 필터 없이 좌표를 그대로 누적하면 수백 미터가 나온다.
      expect(raw, greaterThan(200));
      // 필터를 거치면 유령 거리가 거의 남지 않아야 한다.
      expect(filtered, lessThan(raw / 8));
      expect(filtered, lessThan(40));
    });

    test('실제로 걸으면 거리를 제대로 누적한다', () {
      // 북쪽으로 직진. 4초마다 5.2m씩 = 약 1.3m/s.
      final rnd = Random(7);
      final filter = GpsFilter();
      final start = DateTime(2026, 9, 10, 9);
      const steps = 80;
      const stepM = 5.2;

      var total = 0.0;
      for (var i = 0; i < steps; i++) {
        final lat = _baseLat +
            _latOffset(i * stepM + (rnd.nextDouble() - 0.5) * 3);
        final lng = _baseLng + _lngOffset((rnd.nextDouble() - 0.5) * 3);

        final fix = filter.add(RawFix(
          lat: lat,
          lng: lng,
          accuracy: 6,
          ts: start.add(Duration(seconds: i * 4)),
          deviceSpeedMps: 1.3,
        ));
        total += fix?.deltaM ?? 0;
      }

      // 워밍업으로 버리는 앞 3개 지점을 뺀 기대 거리
      const expected = (steps - GpsFilter.warmupSkip - 1) * stepM;
      expect(total, greaterThan(expected * 0.8));
      expect(total, lessThan(expected * 1.2));
    });

    test('사람이 낼 수 없는 속도로 튄 픽스는 버린다', () {
      final filter = GpsFilter();
      final start = DateTime(2026, 9, 10, 9);

      // 워밍업 통과용
      for (var i = 0; i < 5; i++) {
        filter.add(RawFix(
          lat: _baseLat,
          lng: _baseLng,
          accuracy: 5,
          ts: start.add(Duration(seconds: i * 2)),
          deviceSpeedMps: 0,
        ));
      }

      // 2초 만에 500m 이동 = 250m/s
      final jump = filter.add(RawFix(
        lat: _baseLat + _latOffset(500),
        lng: _baseLng,
        accuracy: 5,
        ts: start.add(const Duration(seconds: 12)),
        deviceSpeedMps: 0,
      ));

      expect(jump, isNull);
    });

    test('정확도가 나쁜 픽스는 아예 받지 않는다', () {
      final filter = GpsFilter();
      final fix = filter.add(RawFix(
        lat: _baseLat,
        lng: _baseLng,
        accuracy: GpsFilter.maxAccuracyM + 1,
        ts: DateTime(2026, 9, 10, 9),
      ));
      expect(fix, isNull);
    });
  });
}
