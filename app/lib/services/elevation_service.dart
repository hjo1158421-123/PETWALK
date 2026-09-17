import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// 고도 조회가 실패했을 때.
class ElevationException implements Exception {
  ElevationException(this.message);
  final String message;

  @override
  String toString() => 'ElevationException: $message';
}

/// [coordKey] 를 좌표 조회 키로 쓴다.
///
/// Open-Elevation 은 좌표 하나하나가 요청 크기다. GPS/OSM 좌표는 소수
/// 7~8자리까지 오는데, 세그먼트 경계에서 미세하게 다른 좌표가 같은
/// 지점을 가리키는 경우가 흔해서 반올림 없이 조회하면 같은 곳을 두 번
/// 묻는 요청이 쌓인다.
String elevationKey(LatLng p) => coordKey(p.latitude, p.longitude);

/// [Open-Elevation](https://open-elevation.com/) 으로 좌표별 고도를 받는다.
///
/// 무료·API 키 불필요. 정확도는 데이터셋(SRTM 90m 격자)에 달려 있어
/// 미터 단위로 딱 맞진 않지만, 세그먼트 경사가 완만한지 가파른지를
/// 가르는 용도로는 충분하다.
class ElevationService {
  ElevationService({
    http.Client? client,
    this.endpoint = 'https://api.open-elevation.com/api/v1/lookup',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;

  /// 좌표별 고도(m)를 [elevationKey] 를 키로 돌려준다.
  ///
  /// 중복 좌표는 한 번만 요청한다 — 세그먼트가 이어질 때 앞 세그먼트의
  /// 끝점과 다음 세그먼트의 시작점이 같은 좌표인 경우가 많다.
  Future<Map<String, double>> fetchElevations(List<LatLng> points) async {
    if (points.isEmpty) return const {};

    final unique = <String, LatLng>{
      for (final p in points) elevationKey(p): p,
    };

    final body = jsonEncode({
      'locations': [
        for (final p in unique.values)
          {'latitude': p.latitude, 'longitude': p.longitude},
      ],
    });

    http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw ElevationException('고도 데이터를 받아오지 못했어요: $e');
    }

    if (res.statusCode != 200) {
      throw ElevationException('고도 서버가 요청을 거부했어요 (HTTP ${res.statusCode})');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw ElevationException('고도 응답을 해석하지 못했어요: $e');
    }

    return parseElevationResponse(json);
  }
}

/// Open-Elevation JSON 응답을 `"lat,lng" → 고도(m)` 맵으로 바꾼다.
/// 네트워크와 분리된 순수 함수라 fixture 로 검증할 수 있다.
Map<String, double> parseElevationResponse(Map<String, dynamic> json) {
  final results = (json['results'] as List?) ?? const [];
  final out = <String, double>{};
  for (final r in results) {
    if (r is! Map) continue;
    final lat = (r['latitude'] as num?)?.toDouble();
    final lng = (r['longitude'] as num?)?.toDouble();
    final elev = (r['elevation'] as num?)?.toDouble();
    if (lat == null || lng == null || elev == null) continue;
    out[elevationKey(LatLng(lat, lng))] = elev;
  }
  return out;
}
