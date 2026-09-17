import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_segment.dart';
import 'geo.dart';

/// Overpass 요청이 실패했을 때. 네트워크 문제와 서버 문제를 구분해 화면에서
/// 다른 안내를 줄 수 있게 메시지를 그대로 들고 있는다.
class OverpassException implements Exception {
  OverpassException(this.message);
  final String message;

  @override
  String toString() => 'OverpassException: $message';
}

/// 세그먼트 하나의 목표 길이. 짧을수록 점수가 촘촘해지지만 세그먼트 수가
/// 늘어 계산량이 커진다. 100m 는 설계 문서에 명시된 값이다.
const double kSegmentTargetLengthM = 100;

/// 이 거리(m) 안에 있으면 "그늘·녹지 근접"으로 본다. 가로수 그늘이
/// 실제로 걷는 사람에게 닿는 범위를 넉넉히 잡은 값이다.
///
/// **근거 없음.** 가로수 캐노피 반경에 관한 표준 수치를 찾지 못해 상식적인
/// 값을 썼다. 실제로 추천이 나가기 시작하면 사용자 반응을 보고 조정할 것.
const double kGreeneryProximityM = 50;

/// OSM 도로망을 가져와 [RouteSegment] 로 쪼갠다.
///
/// **개발 중 이 PC(회사 네트워크)에서는 이 서비스가 동작하지 않는다.**
/// overpass-api.de 로 나가는 요청이 회사 프록시에서 막혀 406 을 받는다 —
/// 같은 URL 을 이 PC 밖에서 호출하면 정상 응답이 온다. Chrome 정책 때와
/// 같은 종류의 제약이라 우회하지 않는다. 파싱 로직은 fixture JSON 으로
/// 검증하고, 실제 네트워크 연동 확인은 실기기(회사 와이파이 아닌 곳)에서
/// 한다.
class OverpassService {
  OverpassService({
    http.Client? client,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String endpoint;

  /// [lat], [lng] 반경 [radiusM] 안의 걸을 수 있는 길과 근처 녹지를 가져와
  /// 세그먼트로 쪼갠다. 차도 전용·자전거 전용은 애초에 쿼리에서 뺀다.
  Future<List<RouteSegment>> fetchSegments({
    required double lat,
    required double lng,
    double radiusM = 1200,
  }) async {
    final query = buildOverpassQuery(lat: lat, lng: lng, radiusM: radiusM);

    http.Response res;
    try {
      res = await _client
          .post(Uri.parse(endpoint), body: {'data': query})
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw OverpassException('OSM 데이터를 받아오지 못했어요: $e');
    }

    if (res.statusCode != 200) {
      throw OverpassException(
          'OSM 서버가 요청을 거부했어요 (HTTP ${res.statusCode})');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw OverpassException('OSM 응답을 해석하지 못했어요: $e');
    }

    return parseOverpassResponse(json);
  }
}

/// 도보로 다닐 만한 길만 화이트리스트로 요청한다.
///
/// 계단(`steps`)은 일부러 뺐다 — 반려견에게 계단은 부담스럽고, 특히
/// Krontveit 2012(docs/권장산책량-근거.md)가 자견 고관절에 위험하다고
/// 지목한 게 계단이다.
const _walkableHighways = [
  'footway',
  'path',
  'pedestrian',
  'residential',
  'living_street',
  'track',
];

/// 반경 안의 도로망과 녹지(공원·숲·가로수줄)를 한 번의 요청으로 받는다.
/// 두 번 나눠 부르면 반경이 겹칠 때마다 요청이 배로 늘어난다.
String buildOverpassQuery({
  required double lat,
  required double lng,
  required double radiusM,
}) {
  final highwayPattern = _walkableHighways.join('|');
  return '[out:json][timeout:25];'
      '('
      'way["highway"~"^($highwayPattern)\$"](around:$radiusM,$lat,$lng);'
      'way["leisure"="park"](around:$radiusM,$lat,$lng);'
      'way["landuse"="forest"](around:$radiusM,$lat,$lng);'
      'way["natural"~"^(wood|tree_row)\$"](around:$radiusM,$lat,$lng);'
      ');'
      'out geom;';
}

/// Overpass JSON 응답을 세그먼트 목록으로 바꾼다.
///
/// 네트워크와 분리된 순수 함수다 — fixture JSON 하나로 파싱·분할·그늘
/// 매칭 로직 전부를 네트워크 없이 검증할 수 있다.
List<RouteSegment> parseOverpassResponse(Map<String, dynamic> json) {
  final elements = (json['elements'] as List?) ?? const [];

  final roadSegments = <RouteSegment>[];
  final greeneryPoints = <LatLng>[];

  for (final el in elements) {
    if (el is! Map) continue;
    if (el['type'] != 'way') continue;

    final geometry = el['geometry'] as List?;
    if (geometry == null || geometry.length < 2) continue;

    final points = [
      for (final g in geometry)
        LatLng((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
    ];

    final tags = (el['tags'] as Map?) ?? const {};
    final highway = tags['highway'] as String?;

    if (highway != null) {
      if (!_walkableHighways.contains(highway)) continue;
      final wayId = 'w${el['id']}';
      roadSegments.addAll(_splitIntoSegments(
        wayId: wayId,
        points: points,
        highway: highway,
        surface: tags['surface'] as String?,
        osmName: tags['name'] as String?,
        sidewalk: tags['sidewalk'] as String?,
      ));
    } else if (tags['leisure'] == 'park' ||
        tags['landuse'] == 'forest' ||
        tags['natural'] == 'wood' ||
        tags['natural'] == 'tree_row') {
      // 녹지는 세그먼트로 쪼갤 필요 없이, 그늘 근접 판정용 좌표로만 쓴다.
      greeneryPoints.addAll(points);
    }
  }

  if (greeneryPoints.isEmpty) return roadSegments;

  return [
    for (final seg in roadSegments)
      seg.copyWith(nearGreenery: _isNearGreenery(seg, greeneryPoints)),
  ];
}

/// way 하나를 [kSegmentTargetLengthM] 안팎 길이의 세그먼트로 자른다.
///
/// 마지막 조각이 10m 보다 짧으면 버린다 — 점수화 대상으로 삼기엔 너무
/// 짧아서 노이즈만 늘린다.
List<RouteSegment> _splitIntoSegments({
  required String wayId,
  required List<LatLng> points,
  required String highway,
  String? surface,
  String? osmName,
  String? sidewalk,
}) {
  final segments = <RouteSegment>[];
  var current = <LatLng>[points.first];
  var accumulated = 0.0;
  var index = 0;

  for (var i = 1; i < points.length; i++) {
    final d = haversineM(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
    current.add(points[i]);
    accumulated += d;

    if (accumulated >= kSegmentTargetLengthM) {
      segments.add(RouteSegment(
        id: '$wayId#${index++}',
        points: List.of(current),
        highway: highway,
        surface: surface,
        osmName: osmName,
        sidewalk: sidewalk,
      ));
      current = [points[i]];
      accumulated = 0;
    }
  }

  if (current.length >= 2 && accumulated >= 10) {
    segments.add(RouteSegment(
      id: '$wayId#${index++}',
      points: current,
      highway: highway,
      surface: surface,
      osmName: osmName,
      sidewalk: sidewalk,
    ));
  }

  return segments;
}

bool _isNearGreenery(RouteSegment seg, List<LatLng> greeneryPoints) {
  final mid = seg.points[seg.points.length ~/ 2];
  for (final g in greeneryPoints) {
    final d = haversineM(mid.latitude, mid.longitude, g.latitude, g.longitude);
    if (d <= kGreeneryProximityM) return true;
  }
  return false;
}
