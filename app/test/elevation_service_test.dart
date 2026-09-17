import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:petwalk/services/elevation_service.dart';

void main() {
  group('elevationKey', () {
    test('소수 5자리로 반올림한다', () {
      expect(elevationKey(const LatLng(37.566512345, 126.978099999)),
          '37.56651,126.97810');
    });

    test('미세하게 다른 좌표도 같은 키로 뭉친다', () {
      // GPS/OSM 오차 수준의 차이(약 1cm)는 사실상 같은 지점이다.
      final a = elevationKey(const LatLng(37.5665123, 126.9780001));
      final b = elevationKey(const LatLng(37.5665124, 126.9780002));
      expect(a, b);
    });
  });

  group('parseElevationResponse', () {
    test('좌표별 고도를 키-값으로 뽑는다', () {
      final result = parseElevationResponse({
        'results': [
          {'latitude': 37.5665, 'longitude': 126.978, 'elevation': 38.0},
          {'latitude': 37.5675, 'longitude': 126.979, 'elevation': 52.5},
        ],
      });

      expect(result[elevationKey(const LatLng(37.5665, 126.978))], 38.0);
      expect(result[elevationKey(const LatLng(37.5675, 126.979))], 52.5);
    });

    test('일부 필드가 빠진 결과는 건너뛴다', () {
      final result = parseElevationResponse({
        'results': [
          {'latitude': 37.5665, 'longitude': 126.978}, // elevation 없음
          {'latitude': 37.5675, 'longitude': 126.979, 'elevation': 50.0},
        ],
      });
      expect(result, hasLength(1));
    });

    test('results 가 없으면 빈 맵을 돌려준다', () {
      expect(parseElevationResponse({}), isEmpty);
    });
  });
}
