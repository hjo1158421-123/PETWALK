import '../models/route_segment.dart';

/// 세그먼트 하나의 점수를 지표별로 쪼개서 담는다.
///
/// 화면에 "왜 이 점수인지" 보여 줄 수 있어야 하고(권장 산책량과 같은
/// 원칙 — docs/권장산책량-근거.md), 나중에 가중치를 조정할 때도 지표별
/// 값이 남아 있어야 무엇이 바뀌는지 추적할 수 있다.
class SegmentScoreBreakdown {
  const SegmentScoreBreakdown({
    required this.surface,
    required this.roadSeparation,
    required this.greenery,
    required this.slope,
  });

  /// 노면 재질. 0(아스팔트)~1(흙·마사토).
  final double surface;

  /// 차도로부터의 분리도. 0(차와 뒤섞임)~1(전용 보행로).
  final double roadSeparation;

  /// 그늘·녹지 근접. 0~1.
  final double greenery;

  /// 경사 완만함. 0(가파름)~1(평지). 고도 데이터가 없으면 중간값(0.5).
  final double slope;

  /// docs/추천-설계.md 의 가중치를 그대로 쓴다. 순환성(10%)은 세그먼트가
  /// 아니라 코스 단위 지표라 여기 없다 — 나머지 네 개(65%)를 100 으로
  /// 다시 스케일링한다.
  static const double _surfaceWeight = 20;
  static const double _roadSeparationWeight = 20;
  static const double _greeneryWeight = 15;
  static const double _slopeWeight = 10;
  static const double _totalWeight =
      _surfaceWeight + _roadSeparationWeight + _greeneryWeight + _slopeWeight;

  /// 0~100 합산 점수.
  double get total =>
      (surface * _surfaceWeight +
          roadSeparation * _roadSeparationWeight +
          greenery * _greeneryWeight +
          slope * _slopeWeight) /
      _totalWeight *
      100;
}

/// [RouteSegment] 를 지표별로 채점한다.
///
/// **값 대부분이 근거 없음이다.** 설계 문서(docs/추천-설계.md)의 가중치
/// 배분(20/20/15/10%)은 상식적 판단이지, 검증된 연구 결과가 아니다.
/// 지표 안에서 구간을 나눈 세부 점수(예: 아스팔트=0.3)도 마찬가지다.
/// `docs/권장산책량-근거.md` 때와 같은 문제라, 실제 사용자 반응(완주율,
/// 재방문 — 설계 문서의 "이력 기반" 절 참조)이 쌓이면 그걸로 보정해야
/// 한다. 지금은 "그럴듯한 순서"만 맞춰 둔 상태다.
class SegmentScorer {
  const SegmentScorer._();

  static SegmentScoreBreakdown score(
    RouteSegment segment, {
    double? gradientPercent,
  }) =>
      SegmentScoreBreakdown(
        surface: _surfaceScore(segment.surface),
        roadSeparation: _roadSeparationScore(segment),
        greenery: segment.nearGreenery ? 1.0 : 0.2,
        slope: _slopeScore(gradientPercent),
      );

  /// OSM `surface` 태그 → 노면 점수.
  ///
  /// **근거 없음.** "흙바닥이 발바닥에 부드럽고 아스팔트는 여름에
  /// 뜨거워진다"는 상식에 기댄 순서다. 실제 지면 온도나 관절 부담을
  /// 측정한 자료로 검증한 적은 없다.
  static double _surfaceScore(String? surface) {
    if (surface == null) return 0.5; // 모름 — 중간값
    const soft = {
      'dirt',
      'earth',
      'ground',
      'unpaved',
      'fine_gravel',
      'compacted',
      'woodchips',
    };
    const grass = {'grass'};
    const stony = {'paving_stones', 'sett', 'cobblestone', 'paved'};
    const hard = {'asphalt', 'concrete', 'concrete:plates'};

    if (soft.contains(surface)) return 1.0;
    if (grass.contains(surface)) return 0.9;
    if (stony.contains(surface)) return 0.6;
    if (hard.contains(surface)) return 0.3;
    return 0.5; // 목록에 없는 값 — 모름과 동일하게 취급
  }

  /// `highway`·`sidewalk` 태그 → 차도 분리도 점수.
  ///
  /// **근거 없음.** OSM 태그 체계에서 유추한 순서다. 보행자 전용 도로가
  /// 가장 안전하고, 인도 없는 찻길이 가장 위험하다는 방향만 확실하다.
  static double _roadSeparationScore(RouteSegment seg) {
    // 애초에 차량이 다니지 않는 전용 보행로.
    const pedestrianOnly = {'footway', 'path', 'pedestrian', 'track'};
    if (pedestrianOnly.contains(seg.highway)) return 1.0;

    switch (seg.sidewalk) {
      case 'separate':
      case 'both':
        return 0.8;
      case 'left':
      case 'right':
        return 0.6;
      case 'no':
      case 'none':
        return 0.3;
      default:
        // sidewalk 태그가 아예 없다 — residential 은 대체로 좁고 느린
        // 도로라 완전한 차도 전용(0.3)보다는 조금 낫게 잡는다.
        return seg.highway == 'living_street' ? 0.6 : 0.4;
    }
  }

  /// 경사(%) → 완만함 점수. 낮을수록(평지일수록) 좋다.
  ///
  /// **근거 없음.** 구간 경계(2/5/10%)도 상식적으로 나눴다. 다만 방향
  /// 자체는 근거가 있다 — 노령견·단두종에게 경사가 부담이라는 건
  /// docs/권장산책량-근거.md 에 정리된 문헌들과 결이 같다.
  static double _slopeScore(double? gradientPercent) {
    if (gradientPercent == null) return 0.5; // 고도 데이터 없음 — 중간값
    final g = gradientPercent.abs();
    if (g <= 2) return 1.0;
    if (g <= 5) return 0.7;
    if (g <= 10) return 0.4;
    return 0.1;
  }
}

/// 세그먼트 시작/끝 고도로 경사(%)를 구한다. 고도를 모르면 null.
double? gradientPercentOf(
  RouteSegment segment, {
  required double? startElevationM,
  required double? endElevationM,
}) {
  if (startElevationM == null || endElevationM == null) return null;
  final length = segment.lengthM;
  if (length <= 0) return null;
  return (endElevationM - startElevationM).abs() / length * 100;
}
