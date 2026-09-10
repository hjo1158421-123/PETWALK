/// 서로 다른 GPS 트랙이 "같은 코스"인지 판정한다.
///
/// 좌표를 직접 비교하면 GPS 오차 때문에 같은 길도 매번 다르게 나온다.
/// 대신 트랙을 geohash 셀 집합으로 바꾼 뒤 Jaccard 유사도를 본다.
/// 셀 하나가 약 150m라 측위 오차는 자연히 흡수된다.
class CourseMatcher {
  /// 같은 코스로 볼 최소 유사도
  static const double threshold = 0.70;

  /// 코스 매칭을 시도할 최소 셀 수. 너무 짧은 산책은 아무 코스에나 붙는다.
  static const int minCells = 4;

  /// 거리 차이 허용 배율. 같은 셀을 지나도 한 바퀴 더 돌았으면 다른 코스다.
  static const double distanceToleranceRatio = 1.35;

  static double jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final inter = a.intersection(b).length;
    if (inter == 0) return 0;
    final union = a.length + b.length - inter;
    return inter / union;
  }

  static bool distanceCompatible(double a, double b) {
    if (a <= 0 || b <= 0) return false;
    final ratio = a > b ? a / b : b / a;
    return ratio <= distanceToleranceRatio;
  }
}
