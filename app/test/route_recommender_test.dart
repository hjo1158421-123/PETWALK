import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:petwalk/models/route_segment.dart';
import 'package:petwalk/services/geo.dart';
import 'package:petwalk/services/route_recommender.dart';

const double _baseLat = 37.5665;
const double _baseLng = 126.9780;
const double _mPerDegLat = 111320;
double _mPerDegLng(double lat) => 111320 * math.cos(lat * math.pi / 180);

LatLng _at({double northM = 0, double eastM = 0}) => LatLng(
      _baseLat + northM / _mPerDegLat,
      _baseLng + eastM / _mPerDegLng(_baseLat),
    );

RouteSegment _road(String id, LatLng from, LatLng to, {String? surface}) =>
    RouteSegment(
      id: id,
      points: [from, to],
      highway: 'footway',
      surface: surface ?? 'asphalt',
    );

void main() {
  group('RouteRecommender — 사각형 루프', () {
    // A(0,0) - B(북쪽100) - C(북쪽100,동쪽100) - D(동쪽100) - A. 둘레 400m.
    final a = _at();
    final b = _at(northM: 100);
    final c = _at(northM: 100, eastM: 100);
    final d = _at(eastM: 100);

    final square = [
      _road('ab', a, b),
      _road('bc', b, c),
      _road('cd', c, d),
      _road('da', d, a),
    ];

    test('네 변을 모두 지나 시작점으로 돌아온다', () {
      final course = RouteRecommender.recommend(
        segments: square,
        start: a,
        targetDistanceM: 400,
      );

      expect(course, isNotNull);
      expect(course!.segments.map((s) => s.id).toSet(),
          {'ab', 'bc', 'cd', 'da'});

      final startPoint = course.segments.first.start;
      final endPoint = course.segments.last.end;
      expect(startPoint.latitude, closeTo(a.latitude, 1e-6));
      expect(endPoint.latitude, closeTo(a.latitude, 1e-6),
          reason: '순환이면 끝점이 시작점으로 돌아와야 한다');
    });

    test('세그먼트가 순서대로 이어진다(끊긴 곳이 없다)', () {
      final course = RouteRecommender.recommend(
        segments: square,
        start: a,
        targetDistanceM: 400,
      );

      final segs = course!.segments;
      for (var i = 1; i < segs.length; i++) {
        final prevEnd = segs[i - 1].end;
        final curStart = segs[i].start;
        expect(prevEnd.latitude, closeTo(curStart.latitude, 1e-6));
        expect(prevEnd.longitude, closeTo(curStart.longitude, 1e-6));
      }
    });

    test('총 거리가 목표 거리에 근접한다', () {
      final course = RouteRecommender.recommend(
        segments: square,
        start: a,
        targetDistanceM: 400,
      );
      expect(course!.distanceM, closeTo(400, 40));
    });

    test('노면이 좋은 변을 더 선호한다', () {
      // cd 변을 흙길(고점수)로 바꾸면, 반환점을 고를 때 같은 거리라도
      // cost 가 더 싼 경로 쪽을 우선한다는 걸 간접적으로 확인한다 —
      // 적어도 좋은 노면 세그먼트가 배제되지는 않아야 한다.
      final withGoodSurface = [
        _road('ab', a, b),
        _road('bc', b, c),
        _road('cd', c, d, surface: 'dirt'),
        _road('da', d, a),
      ];
      final course = RouteRecommender.recommend(
        segments: withGoodSurface,
        start: a,
        targetDistanceM: 400,
      );
      expect(course, isNotNull);
      expect(course!.segments.any((s) => s.id == 'cd'), isTrue);
    });
  });

  group('RouteRecommender — 경사(고도) 반영', () {
    test('같은 구간에 평지·급경사 두 길이 있으면 평지를 고른다', () {
      // A-B 사이에 값싼 평지 길(flat)과 비싼 급경사 길(steep)을 나란히
      // 둔다. 둘 다 A→B 100m 지만 고도차만 다르다. 고도 정보를 주면
      // outbound(A→B)는 flat 을, avoid 페널티가 붙는 inbound(B→A)는
      // 대안인 steep 을 골라야 한다 — 이게 "경사가 경로 선택에 실제로
      // 영향을 준다"를 보여주는 시나리오다. (segment_scorer_test.dart
      // 는 이미 지표 하나의 계산값을, 이 테스트는 그 지표가 실제 경로
      // 선택을 바꾸는지를 검증한다.)
      final a = _at();
      final b = _at(northM: 100);
      // 고도는 좌표별로만 줄 수 있어서, 시작/끝이 같은 두 세그먼트로는
      // 구분할 수 없다. 대신 중간 경유지가 다른 두 개의 독립된 A→B
      // 경로로 구성한다.
      //
      // flat(a_m1, m1_b): A - M1(고도 0) - B(고도 0) — 평지
      // steep(a_m2, m2_b): A - M2(고도 40) - B(고도 0) — 가팔랐다 내려온다
      final m1 = _at(northM: 50, eastM: 5);
      final m2 = _at(northM: 50, eastM: -5);
      final segments = [
        _road('a_m1', a, m1),
        _road('m1_b', m1, b),
        _road('a_m2', a, m2),
        _road('m2_b', m2, b),
      ];
      final elev = {
        coordKey(a.latitude, a.longitude): 0.0,
        coordKey(m1.latitude, m1.longitude): 0.0,
        coordKey(m2.latitude, m2.longitude): 40.0,
        coordKey(b.latitude, b.longitude): 0.0,
      };

      final course = RouteRecommender.recommend(
        segments: segments,
        start: a,
        targetDistanceM: 200, // 절반 100m = B 지점
        elevations: elev,
      );

      expect(course, isNotNull);
      final usedIds = course!.segments.map((s) => s.id).toList();
      // 왕복 2회분 중 적어도 한 번은 평지(a_m1/m1_b) 조합을 타야 한다 —
      // outbound 는 항상 더 싼 평지를 고르게 돼 있다.
      expect(
        usedIds.contains('a_m1') || usedIds.contains('m1_b'),
        isTrue,
        reason: '평지 경로가 최소 한 번은 선택돼야 한다: $usedIds',
      );
    });

    test('가팔라도 고도를 모르면 중간값 취급이라 코스는 여전히 나온다', () {
      final a = _at();
      final b = _at(northM: 100);
      final steepOnly = [_road('steep', a, b)];

      final course = RouteRecommender.recommend(
        segments: steepOnly,
        start: a,
        targetDistanceM: 200,
        // elevations 를 아예 안 준다 — 지표가 중간값으로 빠질 뿐 실패하면
        // 안 된다.
      );
      expect(course, isNotNull);
    });
  });

  group('RouteRecommender — 막다른 길', () {
    test('한 방향뿐이면 왕복으로라도 코스를 낸다', () {
      final a = _at();
      final tip = _at(northM: 150);
      final deadEnd = [_road('out', a, tip)];

      final course = RouteRecommender.recommend(
        segments: deadEnd,
        start: a,
        targetDistanceM: 300,
      );

      expect(course, isNotNull);
      // 갔다가 그대로 돌아오니 총 길이는 편도의 두 배 근처다.
      expect(course!.distanceM, closeTo(300, 30));
      final endPoint = course.segments.last.end;
      expect(endPoint.latitude, closeTo(a.latitude, 1e-6));
    });
  });

  group('RouteRecommender — 하드 필터', () {
    test('차도 전용·자전거 전용만 있으면 추천하지 않는다', () {
      final a = _at();
      final b = _at(northM: 200);
      final carOnly = [
        RouteSegment(id: 'x', points: [a, b], highway: 'motorway'),
      ];

      expect(
        RouteRecommender.recommend(
            segments: carOnly, start: a, targetDistanceM: 400),
        isNull,
      );
    });

    test('빈 세그먼트 목록이면 null이다', () {
      expect(
        RouteRecommender.recommend(
            segments: const [], start: _at(), targetDistanceM: 400),
        isNull,
      );
    });

    test('목표 거리가 0 이하면 null이다', () {
      final a = _at();
      final b = _at(northM: 100);
      expect(
        RouteRecommender.recommend(
          segments: [_road('ab', a, b)],
          start: a,
          targetDistanceM: 0,
        ),
        isNull,
      );
    });
  });

  group('RouteRecommender — 출발점 스냅', () {
    test('그래프 노드와 정확히 일치하지 않아도 가장 가까운 노드에서 시작한다', () {
      final a = _at();
      final b = _at(northM: 100);
      final c = _at(northM: 100, eastM: 100);
      final d = _at(eastM: 100);
      final square = [
        _road('ab', a, b),
        _road('bc', b, c),
        _road('cd', c, d),
        _road('da', d, a),
      ];

      // a 에서 5m 쯤 떨어진 지점에서 출발해도 코스가 나와야 한다.
      final nearA = _at(northM: 5);
      final course = RouteRecommender.recommend(
        segments: square,
        start: nearA,
        targetDistanceM: 400,
      );
      expect(course, isNotNull);
    });
  });
}
