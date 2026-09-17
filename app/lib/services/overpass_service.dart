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
/// **두 단계로 나눠 처리한다.** 처음엔 모든 way 를 개별적으로 100m 씩
/// 잘랐는데, 그러면 실제로 이어진 도로망이 그래프에서 조각조각 끊겨
/// 버렸다 — 실기기에서 노드 수천 개짜리 그래프인데 시작점에서 갈 수
/// 있는 곳이 단 2곳뿐인 현상으로 발견했다.
///
/// 원인은 이렇다. 도로 A 가 0~300m, 도로 B 가 A 의 150m 지점에서
/// 갈라져 나간다고 하자. A 는 100m 단위로만 끊기니 마디가 100m·200m
/// 지점에 생기고, B 의 시작점(150m 지점)은 그 어떤 A 세그먼트의
/// 끝점과도 좌표가 안 맞는다. 실제로는 이어진 길인데 그래프에서는
/// 완전히 분리된 것처럼 보인다.
///
/// 그래서 먼저(1차 패스) 모든 도로 way 의 좌표를 모아 "두 개 이상의
/// way 가 공유하는 좌표"를 교차점으로 찾아 두고, 세그먼트를 자를 때
/// (2차 패스) 100m 마다는 물론 **교차점을 만날 때도** 끊는다. 이러면
/// 교차점 좌표가 양쪽 세그먼트에 정확히 같은 키로 나타나 그래프가
/// 실제 도로망처럼 이어진다.
///
/// 네트워크와 분리된 순수 함수다 — fixture JSON 하나로 파싱·분할·그늘
/// 매칭 로직 전부를 네트워크 없이 검증할 수 있다.
List<RouteSegment> parseOverpassResponse(Map<String, dynamic> json) {
  final elements = (json['elements'] as List?) ?? const [];

  // 1차 패스: 도로 way 를 전부 모으고, 좌표별로 몇 개의 way 가
  // 지나가는지 센다.
  final wayPoints = <String, List<LatLng>>{};
  final wayTags = <String, Map>{};
  final pointToWays = <String, Set<String>>{};
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
      wayPoints[wayId] = points;
      wayTags[wayId] = tags;
      for (final p in points) {
        pointToWays
            .putIfAbsent(coordKey(p.latitude, p.longitude), () => {})
            .add(wayId);
      }
    } else if (tags['leisure'] == 'park' ||
        tags['landuse'] == 'forest' ||
        tags['natural'] == 'wood' ||
        tags['natural'] == 'tree_row') {
      // 녹지는 세그먼트로 쪼갤 필요 없이, 그늘 근접 판정용 좌표로만 쓴다.
      greeneryPoints.addAll(points);
    }
  }

  final intersections = {
    for (final entry in pointToWays.entries)
      if (entry.value.length >= 2) entry.key,
  };

  // 2차 패스: 교차점 + 100m 규칙으로 세그먼트를 만든다.
  final roadSegments = <RouteSegment>[];
  for (final wayId in wayPoints.keys) {
    final tags = wayTags[wayId]!;
    roadSegments.addAll(_splitIntoSegments(
      wayId: wayId,
      points: wayPoints[wayId]!,
      highway: tags['highway'] as String,
      surface: tags['surface'] as String?,
      osmName: tags['name'] as String?,
      sidewalk: tags['sidewalk'] as String?,
      intersections: intersections,
    ));
  }

  if (greeneryPoints.isEmpty) return roadSegments;

  return [
    for (final seg in roadSegments)
      seg.copyWith(nearGreenery: _isNearGreenery(seg, greeneryPoints)),
  ];
}

/// way 하나를 세그먼트로 자른다. 100m 를 채우거나 [intersections] 에 있는
/// 좌표(다른 도로와 만나는 지점)에 닿으면 끊는다.
///
/// 마지막 조각이 10m 보다 짧으면 버린다 — 단, 교차점에서 끊긴 조각은
/// 아무리 짧아도 유지한다. 짧다고 버리면 바로 그 지점에서 그래프
/// 연결이 다시 끊어진다.
List<RouteSegment> _splitIntoSegments({
  required String wayId,
  required List<LatLng> points,
  required String highway,
  String? surface,
  String? osmName,
  String? sidewalk,
  required Set<String> intersections,
}) {
  final segments = <RouteSegment>[];
  var current = <LatLng>[points.first];
  var accumulated = 0.0;
  var index = 0;

  void flush() {
    if (current.length < 2) return;
    segments.add(RouteSegment(
      id: '$wayId#${index++}',
      points: List.of(current),
      highway: highway,
      surface: surface,
      osmName: osmName,
      sidewalk: sidewalk,
    ));
  }

  for (var i = 1; i < points.length; i++) {
    final d = haversineM(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
    current.add(points[i]);
    accumulated += d;

    // way 의 맨 끝점은 어차피 루프 뒤에서 처리하니, 중간 지점에서만
    // 교차점 여부를 본다.
    final isLast = i == points.length - 1;
    final atIntersection = !isLast &&
        intersections.contains(coordKey(points[i].latitude, points[i].longitude));

    if (accumulated >= kSegmentTargetLengthM || atIntersection) {
      flush();
      current = [points[i]];
      accumulated = 0;
    }
  }

  // way 끝에서 남은 자투리. 100m 도 못 채우고 교차점도 아니라서 루프
  // 안에서 못 끊긴 진짜 마지막 조각이다 — 이것만 10m 미만이면 버린다.
  // (교차점에서 끊긴 조각은 이미 위에서 flush 돼 여기 안 걸린다.)
  if (accumulated >= 10) flush();

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
