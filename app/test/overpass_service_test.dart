import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/services/geo.dart';
import 'package:petwalk/services/overpass_service.dart';

/// 서울시청 근처 좌표. 위경도 1도가 약 111km 라는 사실만 알면 되는
/// 계산에 쓴다.
const double _baseLat = 37.5665;
const double _baseLng = 126.9780;
const double _mPerDegLat = 111320;

double _lat(double northM) => _baseLat + northM / _mPerDegLat;

void main() {
  group('buildOverpassQuery', () {
    test('걸을 수 있는 길만 화이트리스트로 요청한다', () {
      final q = buildOverpassQuery(lat: _baseLat, lng: _baseLng, radiusM: 500);

      expect(q, contains('footway'));
      expect(q, contains('residential'));
      // 차도 전용·자전거 전용·계단은 애초에 쿼리에 넣지 않는다.
      expect(q, isNot(contains('motorway')));
      expect(q, isNot(contains('cycleway')));
      expect(q, isNot(contains('steps')));
    });

    test('반경과 중심 좌표가 쿼리에 그대로 들어간다', () {
      final q = buildOverpassQuery(lat: 37.1, lng: 127.2, radiusM: 800);
      expect(q, contains('around:800.0,37.1,127.2'));
    });
  });

  group('parseOverpassResponse', () {
    test('way 하나를 목표 길이(100m)씩 세그먼트로 자른다', () {
      // 북쪽으로 270m 짜리 직선 도로. 30m 간격 점 10개.
      //
      // 30m 간격을 쓴 이유: 25m 간격(4개 합=100.0)으로 하면 부동소수점
      // 오차로 합계가 100.0 에 정확히 못 미쳐(99.999...) 세그먼트 경계가
      // 한 칸씩 밀리는 일이 실제로 있었다. 30m 간격이면 세그먼트 경계가
      // 90m/120m 처럼 100 에서 확실히 떨어져 있어 오차가 결과를 못 바꾼다.
      final geometry = [
        for (var i = 0; i <= 9; i++) {'lat': _lat(i * 30.0), 'lon': _baseLng}
      ];

      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 1,
            'geometry': geometry,
            'tags': {'highway': 'footway', 'surface': 'asphalt'},
          }
        ],
      });

      // 4구간(120m)째에 100m 를 넘어 끊긴다 — 120 / 120 / 30(마지막) = 3개.
      expect(segments, hasLength(3));
      expect(segments[0].id, 'w1#0');
      expect(segments[1].id, 'w1#1');
      expect(segments[0].lengthM, closeTo(120, 0.5));
      expect(segments[2].lengthM, closeTo(30, 0.5));
      expect(segments.every((s) => s.highway == 'footway'), isTrue);
      expect(segments.every((s) => s.surface == 'asphalt'), isTrue);

      // 세그먼트가 이어져야 한다 — 앞 세그먼트의 끝점이 다음 세그먼트의
      // 시작점이어야 경로에 빈틈이 생기지 않는다.
      expect(segments[0].end, segments[1].start);
    });

    test('짧은 길은 한 세그먼트로, 너무 짧은 마지막 조각은 버린다', () {
      // 105m: 100m 세그먼트 하나 + 5m 남는 조각(버려짐).
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 2,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(100), 'lon': _baseLng},
              {'lat': _lat(105), 'lon': _baseLng},
            ],
            'tags': {'highway': 'path'},
          }
        ],
      });

      expect(segments, hasLength(1));
    });

    test('차도 전용·자전거 전용 도로는 걸러낸다', () {
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 3,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(200), 'lon': _baseLng},
            ],
            'tags': {'highway': 'motorway'},
          },
          {
            'type': 'way',
            'id': 4,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(200), 'lon': _baseLng},
            ],
            'tags': {'highway': 'cycleway'},
          },
        ],
      });

      expect(segments, isEmpty);
    });

    test('공원·가로수 근처 세그먼트에 nearGreenery 를 표시한다', () {
      // 그늘 판정은 세그먼트 좌표 목록의 "가운데 인덱스" 점을 기준으로
      // 삼는다. 점 간격이 100 의 배수(50m x 2 등)이면 부동소수점 오차로
      // 누적합이 100.0 에 못 미쳐 세그먼트 경계가 밀리는 문제가 실제로
      // 있었다(30m/40m 간격처럼 100 의 배수가 아닌 값을 쓸 것).
      final geometry = [
        for (var i = 0; i <= 4; i++) {'lat': _lat(i * 40.0), 'lon': _baseLng}
      ];

      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 5,
            'geometry': geometry,
            'tags': {'highway': 'footway'},
          },
          {
            // 첫 세그먼트(0~120m, 중간 인덱스는 80m 지점)에 붙어 있는 공원.
            // 점이 2개 미만인 way 는 도로와 마찬가지로 통째로 건너뛰므로
            // (실제 OSM 폴리곤도 항상 여러 점이다) 여기서도 최소 2점을 준다.
            'type': 'way',
            'id': 6,
            'geometry': [
              {'lat': _lat(85), 'lon': _baseLng + 0.0002},
              {'lat': _lat(90), 'lon': _baseLng + 0.0003},
            ],
            'tags': {'leisure': 'park'},
          },
          {
            // 아주 멀리 떨어진(약 5km) 숲 — 어떤 세그먼트에도 안 붙는다.
            'type': 'way',
            'id': 7,
            'geometry': [
              {'lat': _lat(5000), 'lon': _baseLng},
              {'lat': _lat(5010), 'lon': _baseLng},
            ],
            'tags': {'landuse': 'forest'},
          },
        ],
      });

      final roadSegments =
          segments.where((s) => s.highway == 'footway').toList();
      expect(roadSegments, isNotEmpty);
      expect(roadSegments.any((s) => s.nearGreenery), isTrue,
          reason: '공원에서 가까운 세그먼트가 하나는 있어야 한다');
    });

    test('녹지가 전혀 없으면 모든 세그먼트가 nearGreenery=false 다', () {
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 8,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(150), 'lon': _baseLng},
            ],
            'tags': {'highway': 'footway'},
          },
        ],
      });

      expect(segments.every((s) => !s.nearGreenery), isTrue);
    });

    test('elements 가 비어 있으면 빈 목록을 돌려준다', () {
      expect(parseOverpassResponse({'elements': []}), isEmpty);
      expect(parseOverpassResponse({}), isEmpty);
    });

    test('geometry 가 1개뿐인 way(점 하나)는 건너뛴다', () {
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 9,
            'geometry': [
              {'lat': _baseLat, 'lon': _baseLng}
            ],
            'tags': {'highway': 'footway'},
          },
        ],
      });
      expect(segments, isEmpty);
    });
  });

  group('RouteSegment', () {
    test('lengthM 은 좌표 사이 거리의 합이다', () {
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 10,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(30), 'lon': _baseLng},
            ],
            'tags': {'highway': 'footway'},
          },
        ],
      });

      expect(segments.single.lengthM, closeTo(30, 1));
    });

    test('isCarOrCycleOnly 가 방향을 정확히 가른다', () {
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 11,
            'geometry': [
              {'lat': _lat(0), 'lon': _baseLng},
              {'lat': _lat(150), 'lon': _baseLng},
            ],
            'tags': {'highway': 'residential'},
          },
        ],
      });
      expect(segments.single.isCarOrCycleOnly, isFalse);
    });
  });

  group('parseOverpassResponse — 교차점 (회귀 방지)', () {
    // 실기기에서 실제로 겪은 버그: 도로 A(0~300m)를 100m 단위로만 자르면
    // 마디가 100m·200m 지점에만 생긴다. 도로 B 가 A 의 150m 지점(세그먼트
    // "중간")에서 갈라져 나가면, B 의 시작점은 A 의 어떤 세그먼트 끝점과도
    // 좌표가 안 맞아 그래프에서 완전히 분리된다 — 노드 수천 개짜리
    // 그래프인데 시작점에서 갈 수 있는 곳이 2곳뿐인 현상으로 나타났다.
    // 지금은 교차점에서도 강제로 끊어서 이 문제를 막는다.

    test('다른 way 와 만나는 지점에서도 세그먼트가 끊긴다', () {
      // A: 0m ~ 300m 직선(교차점을 포함하지 않는 50m 간격 점들).
      final aPoints = [
        for (var i = 0; i <= 6; i++) {'lat': _lat(i * 50.0), 'lon': _baseLng}
      ];
      // B: A 의 150m 지점(=A 의 세그먼트 "중간")에서 동쪽으로 갈라진다.
      final crossingLat = _lat(150);
      final bPoints = [
        {'lat': crossingLat, 'lon': _baseLng},
        {'lat': crossingLat, 'lon': _baseLng + 0.001},
      ];

      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 100,
            'geometry': aPoints,
            'tags': {'highway': 'residential'},
          },
          {
            'type': 'way',
            'id': 200,
            'geometry': bPoints,
            'tags': {'highway': 'footway'},
          },
        ],
      });

      final crossingKey = coordKey(crossingLat, _baseLng);
      final aEndpointKeys = {
        for (final s in segments)
          if (s.id.startsWith('w100#')) ...[
            coordKey(s.start.latitude, s.start.longitude),
            coordKey(s.end.latitude, s.end.longitude),
          ],
      };

      expect(aEndpointKeys, contains(crossingKey),
          reason: 'A 가 150m 지점(B 와의 교차점)에서 끊기지 않으면 '
              'B 와 그래프로 이어지지 않는다');
    });

    test('교차점이 없으면 100m 단위로만 자른다(기존 동작 유지)', () {
      final points = [
        for (var i = 0; i <= 9; i++) {'lat': _lat(i * 30.0), 'lon': _baseLng}
      ];
      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 300,
            'geometry': points,
            'tags': {'highway': 'footway'},
          },
        ],
      });

      // 이전과 동일하게 120/120/30(마지막) = 3개여야 한다.
      expect(segments, hasLength(3));
    });

    test('교차점끼리 가까우면 그 사이 짧은 조각도 버려지지 않는다', () {
      // A 는 0~200m. 100m 지점에서 B 와, 105m 지점에서 C 와 만난다.
      // 100~105m 사이의 5m 짜리 조각은 순전히 두 교차점 때문에 강제로
      // 끊긴 것이라, "10m 미만이면 버린다"는 규칙에 걸리면 안 된다 —
      // 걸리면 B·C 양쪽과의 그래프 연결이 그 자리에서 끊어진다.
      final aPoints = [
        {'lat': _lat(0), 'lon': _baseLng},
        {'lat': _lat(100), 'lon': _baseLng},
        {'lat': _lat(105), 'lon': _baseLng},
        {'lat': _lat(200), 'lon': _baseLng},
      ];
      final b = [
        {'lat': _lat(100), 'lon': _baseLng},
        {'lat': _lat(100), 'lon': _baseLng + 0.001},
      ];
      final c = [
        {'lat': _lat(105), 'lon': _baseLng},
        {'lat': _lat(105), 'lon': _baseLng + 0.001},
      ];

      final segments = parseOverpassResponse({
        'elements': [
          {
            'type': 'way',
            'id': 400,
            'geometry': aPoints,
            'tags': {'highway': 'footway'},
          },
          {'type': 'way', 'id': 500, 'geometry': b, 'tags': {'highway': 'footway'}},
          {'type': 'way', 'id': 600, 'geometry': c, 'tags': {'highway': 'footway'}},
        ],
      });

      final aSegments =
          segments.where((s) => s.id.startsWith('w400#')).toList();
      // [0-100] · [100-105](5m, 교차점 사이) · [105-200] = 3개.
      // 짧다고 가운데 조각이 버려지면 2개가 된다.
      expect(aSegments, hasLength(3));
      expect(
        aSegments.map((s) => s.lengthM).reduce((a, b) => a + b),
        closeTo(200, 1),
      );
    });
  });
}
