import 'dart:math' as math;

const double _earthRadiusM = 6371008.8;

/// 두 좌표 사이의 대권 거리 (m).
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusM * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// 좌표를 소수 [precision] 자리로 반올림해 문자열 키로 만든다.
/// 기본 5자리는 약 1.1m 격자다.
///
/// 미세하게 다른 좌표(부동소수점 오차, GPS/OSM 소스 차이)를 "같은 지점"
/// 으로 묶어야 하는 자리마다 쓴다 — 고도 조회 캐시 키(`ElevationService`),
/// 추천 엔진 그래프의 교차점 판별(`RouteRecommender`) 둘 다 여기서 쓴다.
String coordKey(double lat, double lng, {int precision = 5}) =>
    '${lat.toStringAsFixed(precision)},${lng.toStringAsFixed(precision)}';

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// geohash 인코딩.
///
/// precision 7 = 약 153m x 153m 셀. GPS 오차(±10~20m)를 흡수하면서도
/// 다른 길과는 구분되는 크기라 코스 매칭 기본값으로 쓴다.
String geohashEncode(double lat, double lng, {int precision = 7}) {
  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  var even = true;
  var bit = 0, ch = 0;
  final out = StringBuffer();

  while (out.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (lng > mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat > mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    even = !even;
    if (++bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}
