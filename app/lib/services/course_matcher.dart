/// 서로 다른 GPS 트랙이 "같은 코스"인지 판정한다.
///
/// 좌표를 직접 비교하면 GPS 오차 때문에 같은 길도 매번 다르게 나온다.
/// 대신 트랙을 geohash 셀 집합으로 바꿔서 겹치는 정도를 본다.
/// 셀 하나가 약 150m라 측위 오차는 자연히 흡수된다.
class CourseMatcher {
  /// 같은 코스로 볼 최소 겹침 비율
  static const double threshold = 0.75;

  /// 코스 매칭을 시도할 최소 셀 수. 너무 짧은 산책은 아무 코스에나 붙는다.
  static const int minCells = 4;

  /// 거리 차이 허용 배율. 같은 셀을 지나도 한 바퀴 더 돌았으면 다른 코스다.
  static const double distanceToleranceRatio = 1.35;

  /// 포함 계수 — 교집합을 "작은 쪽" 집합 크기로 나눈다.
  ///
  /// Jaccard(교집합/합집합)를 쓰지 않는 이유가 두 가지 있다.
  ///
  /// 첫째, 짧은 코스에 지나치게 가혹하다. 5셀짜리 코스에서 셀 하나만
  /// 어긋나도 Jaccard는 4/6 = 0.67로 떨어진다. 750m 산책에서 한 블록
  /// 돌아간 것뿐인데 다른 코스로 갈라진다.
  ///
  /// 둘째, 코스는 산책을 거듭할수록 셀을 흡수해 커진다. Jaccard는 이때
  /// 분모만 계속 불어나서, 오래된 코스일수록 정작 자기 자신과도 매칭이
  /// 안 되는 역설이 생긴다.
  ///
  /// 포함 계수는 "이번 산책이 코스 위에 얼마나 올라가 있나"를 재기 때문에
  /// 코스가 커져도 값이 흔들리지 않는다. 짧은 산책이 긴 코스의 일부에
  /// 얹혀서 매칭되는 문제는 [distanceCompatible] 로 따로 막는다.
  static double overlap(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final inter = a.intersection(b).length;
    if (inter == 0) return 0;
    return inter / (a.length < b.length ? a.length : b.length);
  }

  static bool distanceCompatible(double a, double b) {
    if (a <= 0 || b <= 0) return false;
    final ratio = a > b ? a / b : b / a;
    return ratio <= distanceToleranceRatio;
  }
}
