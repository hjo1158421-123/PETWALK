/// 화면 표기용 포맷터 모음.
class Fmt {
  /// 1km 미만은 m, 이상은 km로.
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// 산책은 속도(km/h)보다 페이스(분/km)가 감이 온다.
  static String pace(double metersPerSecond) {
    if (metersPerSecond < 0.1) return '--\'--"';
    final secPerKm = 1000 / metersPerSecond;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  static String speedKmh(double metersPerSecond) =>
      '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';

  static String percent(double ratio) => '${(ratio * 100).round()}%';

  static String dateTime(DateTime dt) {
    final md = '${dt.month}월 ${dt.day}일';
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$md $hm';
  }

  static String relativeDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return '${dt.year}.${dt.month}.${dt.day}';
  }
}
