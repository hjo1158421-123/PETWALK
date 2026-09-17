import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/recommended_course.dart';

/// 추천 코스 하나를 지도에 그린다.
///
/// `RouteMap`(위젯)은 실제로 걸은 `TrackPoint` 기록을 그리는 전용이라
/// 걷기 전의 좌표 목록(`RecommendedCourse`)에는 맞지 않는다. 목적이
/// 다르므로 억지로 하나로 합치지 않고 따로 둔다.
class RecommendedRouteMap extends StatelessWidget {
  const RecommendedRouteMap({super.key, required this.course});

  final RecommendedCourse course;

  /// 위젯 테스트에서 타일 요청이 프레임을 계속 붙잡는 걸 막는 스위치.
  /// RouteMap 과 같은 이유(위젯 테스트 안에서 pumpAndSettle 이 안 끝남).
  @visibleForTesting
  static bool tilesEnabled = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allPoints = [
      for (final seg in course.segments) ...seg.points,
    ];
    if (allPoints.isEmpty) {
      return const Center(child: Text('표시할 경로가 없어요.'));
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(allPoints),
          padding: const EdgeInsets.all(40),
        ),
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        if (tilesEnabled)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.petwalk.app',
            maxNativeZoom: 19,
          ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: allPoints,
              color: scheme.primary,
              strokeWidth: 5,
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: allPoints.first,
              width: 18,
              height: 18,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
