import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:petwalk/services/elevation_service.dart';
import 'package:petwalk/services/overpass_service.dart';
import 'package:petwalk/services/recommendation_service.dart';

const double _baseLat = 37.5665;
const double _baseLng = 126.9780;
const double _mPerDegLat = 111320;
double _mPerDegLng(double lat) => 111320 * math.cos(lat * math.pi / 180);
LatLng _at({double northM = 0, double eastM = 0}) => LatLng(
      _baseLat + northM / _mPerDegLat,
      _baseLng + eastM / _mPerDegLng(_baseLat),
    );

Map<String, Object?> _geo(LatLng p) => {'lat': p.latitude, 'lon': p.longitude};

void main() {
  group('RecommendationService — 전체 파이프라인', () {
    test('Overpass → Elevation → 코스 생성까지 실제로 이어진다', () async {
      // 100m 사각형 도로망을 Overpass 응답인 척 돌려준다.
      final a = _at();
      final b = _at(northM: 100);
      final c = _at(northM: 100, eastM: 100);
      final d = _at(eastM: 100);

      final overpassClient = MockClient((request) async {
        expect(request.url.host, 'overpass-api.de');
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'way',
                'id': 1,
                'geometry': [_geo(a), _geo(b)],
                'tags': {'highway': 'footway'},
              },
              {
                'type': 'way',
                'id': 2,
                'geometry': [_geo(b), _geo(c)],
                'tags': {'highway': 'footway'},
              },
              {
                'type': 'way',
                'id': 3,
                'geometry': [_geo(c), _geo(d)],
                'tags': {'highway': 'footway'},
              },
              {
                'type': 'way',
                'id': 4,
                'geometry': [_geo(d), _geo(a)],
                'tags': {'highway': 'footway'},
              },
            ],
          }),
          200,
        );
      });

      final elevationClient = MockClient((request) async {
        expect(request.url.host, 'api.open-elevation.com');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final locations = body['locations'] as List;
        return http.Response(
          jsonEncode({
            'results': [
              for (final loc in locations)
                {
                  'latitude': loc['latitude'],
                  'longitude': loc['longitude'],
                  'elevation': 20.0, // 전부 평지
                },
            ],
          }),
          200,
        );
      });

      final service = RecommendationService(
        overpass: OverpassService(client: overpassClient),
        elevation: ElevationService(client: elevationClient),
      );

      final course = await service.recommendNear(
        start: a,
        targetDistanceM: 400,
      );

      expect(course, isNotNull);
      expect(course!.segments, isNotEmpty);
      expect(course.distanceM, greaterThan(0));
    });

    test('Overpass 요청이 실패하면 OverpassException 이 그대로 올라간다', () async {
      final failingClient =
          MockClient((request) async => http.Response('error', 500));

      final service = RecommendationService(
        overpass: OverpassService(client: failingClient),
        elevation: ElevationService(client: failingClient),
      );

      expect(
        () => service.recommendNear(start: _at(), targetDistanceM: 400),
        throwsA(isA<OverpassException>()),
      );
    });

    test('고도 조회가 실패해도 추천은 계속된다', () async {
      final a = _at();
      final b = _at(northM: 100);
      final c = _at(northM: 100, eastM: 100);
      final d = _at(eastM: 100);

      final overpassClient = MockClient((request) async => http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'way',
                  'id': 1,
                  'geometry': [_geo(a), _geo(b)],
                  'tags': {'highway': 'footway'},
                },
                {
                  'type': 'way',
                  'id': 2,
                  'geometry': [_geo(b), _geo(c)],
                  'tags': {'highway': 'footway'},
                },
                {
                  'type': 'way',
                  'id': 3,
                  'geometry': [_geo(c), _geo(d)],
                  'tags': {'highway': 'footway'},
                },
                {
                  'type': 'way',
                  'id': 4,
                  'geometry': [_geo(d), _geo(a)],
                  'tags': {'highway': 'footway'},
                },
              ],
            }),
            200,
          ));
      // 고도 서버는 죽어 있다고 가정.
      final brokenElevationClient =
          MockClient((request) async => http.Response('down', 503));

      final service = RecommendationService(
        overpass: OverpassService(client: overpassClient),
        elevation: ElevationService(client: brokenElevationClient),
      );

      final course =
          await service.recommendNear(start: a, targetDistanceM: 400);

      // 고도 없이도(경사 지표는 중간값으로) 코스는 나와야 한다.
      expect(course, isNotNull);
    });

    test('주변에 길이 전혀 없으면 null이다', () async {
      final emptyClient = MockClient(
          (request) async => http.Response(jsonEncode({'elements': []}), 200));

      final service = RecommendationService(
        overpass: OverpassService(client: emptyClient),
        elevation: ElevationService(client: emptyClient),
      );

      final course =
          await service.recommendNear(start: _at(), targetDistanceM: 400);
      expect(course, isNull);
    });
  });
}
