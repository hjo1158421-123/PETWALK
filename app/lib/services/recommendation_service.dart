import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/recommended_course.dart';
import 'elevation_service.dart';
import 'overpass_service.dart';
import 'route_recommender.dart';

/// 추천 파이프라인 전체(OSM 도로망 → 고도 → 점수화 → 코스 생성)를
/// 한 번의 호출로 묶는다. 화면은 이 서비스 하나만 알면 된다.
class RecommendationService {
  RecommendationService({
    OverpassService? overpass,
    ElevationService? elevation,
  })  : _overpass = overpass ?? OverpassService(),
        _elevation = elevation ?? ElevationService();

  final OverpassService _overpass;
  final ElevationService _elevation;

  /// [start] 근처에서 [targetDistanceM] 에 가까운 순환 코스를 찾는다.
  /// 적합한 길을 못 찾으면(반경 안에 걸을 만한 길이 없거나, 순환 경로를
  /// 못 만들면) null.
  ///
  /// OSM 요청이 실패하면 [OverpassException] 이 그대로 올라간다 — 화면이
  /// "OSM 데이터를 못 가져왔다"고 정확히 안내할 수 있어야 하기 때문이다.
  /// 반대로 고도 조회 실패는 여기서 삼킨다 — 경사 지표가 중간값으로
  /// 빠질 뿐 추천 자체를 막을 이유는 아니다.
  Future<RecommendedCourse?> recommendNear({
    required LatLng start,
    required double targetDistanceM,
  }) async {
    // 왕복 루프라 편도(절반)만큼만 벌어지면 충분하다. 여유를 조금 두되
    // 너무 넓히면 Overpass 응답이 커져 느려진다.
    final radiusM = (targetDistanceM * 0.6).clamp(300, 3000).toDouble();

    final segments = await _overpass.fetchSegments(
      lat: start.latitude,
      lng: start.longitude,
      radiusM: radiusM,
    );
    if (segments.isEmpty) return null;

    final points = <LatLng>{};
    for (final s in segments) {
      points
        ..add(s.start)
        ..add(s.end);
    }

    var elevations = const <String, double>{};
    try {
      elevations = await _elevation.fetchElevations(points.toList());
    } catch (e) {
      debugPrint('고도 조회 실패 — 경사 지표 없이 계속합니다: $e');
    }

    return RouteRecommender.recommend(
      segments: segments,
      start: start,
      targetDistanceM: targetDistanceM,
      elevations: elevations,
    );
  }
}
