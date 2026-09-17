import 'route_segment.dart';
import 'walk_goal.dart';

/// 추천 엔진이 만들어낸 순환 코스 하나.
class RecommendedCourse {
  const RecommendedCourse({
    required this.segments,
    required this.distanceM,
    required this.averageScore,
  });

  /// 시작점부터 순서대로 이어지는 세그먼트. 끝 세그먼트의 끝점이 다시
  /// 시작점 근처로 돌아온다(순환).
  final List<RouteSegment> segments;

  final double distanceM;

  /// 세그먼트별 [SegmentScoreBreakdown.total] 을 거리로 가중평균한 값.
  /// 짧은 세그먼트 하나가 통째로 점수를 흔들지 않게 하기 위함이다.
  final double averageScore;

  /// 걸음 속도 가정치로 환산한 예상 소요 시간(분).
  ///
  /// `WalkGoal.walkPaceMPerMin` 과 같은 값을 쓴다 — 앱 안에서 "걸음 속도"를
  /// 두 군데서 다르게 가정하면 화면마다 예상 시간이 미묘하게 어긋나
  /// 보인다. 이 값도 **근거 없음**이다(docs/권장산책량-근거.md 참조).
  int get estimatedMinutes =>
      (distanceM / WalkGoal.walkPaceMPerMin).round();
}
