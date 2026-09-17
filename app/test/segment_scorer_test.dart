import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:petwalk/models/route_segment.dart';
import 'package:petwalk/services/segment_scorer.dart';

RouteSegment _seg({
  String? surface,
  String highway = 'footway',
  String? sidewalk,
  bool nearGreenery = false,
}) =>
    RouteSegment(
      id: 'test',
      points: const [LatLng(37.5665, 126.9780), LatLng(37.5675, 126.9780)],
      highway: highway,
      surface: surface,
      sidewalk: sidewalk,
      nearGreenery: nearGreenery,
    );

void main() {
  group('SegmentScorer — 노면 재질', () {
    test('흙·마사토류가 가장 높고 아스팔트가 가장 낮다', () {
      final dirt = SegmentScorer.score(_seg(surface: 'dirt'));
      final asphalt = SegmentScorer.score(_seg(surface: 'asphalt'));
      expect(dirt.surface, greaterThan(asphalt.surface));
      expect(dirt.surface, 1.0);
      expect(asphalt.surface, 0.3);
    });

    test('잔디는 흙보다 살짝 낮고 아스팔트보다는 훨씬 높다', () {
      final grass = SegmentScorer.score(_seg(surface: 'grass'));
      expect(grass.surface, 0.9);
    });

    test('모르는 값과 태그 없음은 중간값으로 취급한다', () {
      final unknown = SegmentScorer.score(_seg(surface: 'metal'));
      final none = SegmentScorer.score(_seg(surface: null));
      expect(unknown.surface, 0.5);
      expect(none.surface, 0.5);
    });
  });

  group('SegmentScorer — 차도 분리도', () {
    test('보행자 전용 도로는 만점이다', () {
      for (final h in ['footway', 'path', 'pedestrian', 'track']) {
        final s = SegmentScorer.score(_seg(highway: h));
        expect(s.roadSeparation, 1.0, reason: '$h 는 만점이어야 한다');
      }
    });

    test('인도가 있으면 없을 때보다 높다', () {
      final withSidewalk = SegmentScorer.score(
          _seg(highway: 'residential', sidewalk: 'both'));
      final noSidewalk =
          SegmentScorer.score(_seg(highway: 'residential', sidewalk: 'no'));
      expect(withSidewalk.roadSeparation, greaterThan(noSidewalk.roadSeparation));
    });

    test('한쪽 인도는 양쪽 인도보다 낮다', () {
      final both = SegmentScorer.score(
          _seg(highway: 'residential', sidewalk: 'both'));
      final oneSide = SegmentScorer.score(
          _seg(highway: 'residential', sidewalk: 'left'));
      expect(both.roadSeparation, greaterThan(oneSide.roadSeparation));
    });
  });

  group('SegmentScorer — 그늘·녹지', () {
    test('근처에 녹지가 있으면 없을 때보다 점수가 높다', () {
      final near = SegmentScorer.score(_seg(nearGreenery: true));
      final far = SegmentScorer.score(_seg(nearGreenery: false));
      expect(near.greenery, greaterThan(far.greenery));
      expect(near.greenery, 1.0);
    });
  });

  group('SegmentScorer — 경사', () {
    test('평지가 가장 높고 급경사가 가장 낮다', () {
      final flat = SegmentScorer.score(_seg(), gradientPercent: 1);
      final steep = SegmentScorer.score(_seg(), gradientPercent: 15);
      expect(flat.slope, greaterThan(steep.slope));
      expect(flat.slope, 1.0);
      expect(steep.slope, 0.1);
    });

    test('오르막 내리막 구분 없이 경사 크기만 본다', () {
      final up = SegmentScorer.score(_seg(), gradientPercent: 8);
      final down = SegmentScorer.score(_seg(), gradientPercent: -8);
      expect(up.slope, down.slope);
    });

    test('고도 데이터가 없으면 중간값이다', () {
      final unknown = SegmentScorer.score(_seg(), gradientPercent: null);
      expect(unknown.slope, 0.5);
    });
  });

  group('SegmentScoreBreakdown.total', () {
    test('모든 지표가 만점이면 총점도 100이다', () {
      const perfect = SegmentScoreBreakdown(
        surface: 1.0,
        roadSeparation: 1.0,
        greenery: 1.0,
        slope: 1.0,
      );
      expect(perfect.total, 100.0);
    });

    test('모든 지표가 0이면 총점도 0이다', () {
      const worst = SegmentScoreBreakdown(
        surface: 0,
        roadSeparation: 0,
        greenery: 0,
        slope: 0,
      );
      expect(worst.total, 0.0);
    });

    test('노면 재질이 가장 무겁게 반영된다(그늘·경사보다 가중치가 크다)', () {
      // 설계 문서 가중치: 노면 20% vs 그늘 15%, 경사 10%.
      const surfaceOnly = SegmentScoreBreakdown(
          surface: 1.0, roadSeparation: 0, greenery: 0, slope: 0);
      const greeneryOnly = SegmentScoreBreakdown(
          surface: 0, roadSeparation: 0, greenery: 1.0, slope: 0);
      expect(surfaceOnly.total, greaterThan(greeneryOnly.total));
    });
  });

  group('gradientPercentOf', () {
    test('고도차와 거리로 경사(%)를 구한다', () {
      final seg = _seg(); // 두 점 사이 약 111.2m (위도 0.001도 차이)
      final g = gradientPercentOf(seg,
          startElevationM: 10, endElevationM: 20);
      // 10m 상승 / 약 111m 거리 ≈ 9%
      expect(g, closeTo(9.0, 1.0));
    });

    test('고도를 모르면 null이다', () {
      final seg = _seg();
      expect(
        gradientPercentOf(seg, startElevationM: null, endElevationM: 20),
        isNull,
      );
    });
  });
}
