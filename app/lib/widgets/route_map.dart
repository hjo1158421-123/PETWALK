import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/track_point.dart';

/// 경로를 그리는 지도.
///
/// 지금은 OSM 타일을 쓴다. 국내 서비스로 나갈 땐 네이버/카카오 지도 SDK로
/// 갈아타야 하는데(도보 경로와 건물 표현 품질 차이), 교체 지점을 이 위젯
/// 하나로 묶어 두었다. 바깥에서는 TrackPoint 리스트만 넘긴다.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.segments,
    this.follow = false,
    this.fitToRoute = false,
    this.initialCenter,
    this.showEndpoints = true,
  });

  /// 일시정지로 끊긴 구간별 좌표 목록
  final List<List<TrackPoint>> segments;

  /// 마지막 지점을 따라 카메라를 이동시킬지 (기록 중 화면)
  final bool follow;

  /// 경로 전체가 보이도록 맞출지 (이력 상세 화면)
  final bool fitToRoute;

  final LatLng? initialCenter;
  final bool showEndpoints;

  /// 테스트에서 지도 타일을 끄기 위한 스위치.
  ///
  /// 위젯 테스트에서는 타일 요청이 전부 실패하는데, flutter_map 이 계속
  /// 재시도하면서 프레임이 멈추지 않아 테스트가 끝나지 않는다.
  @visibleForTesting
  static bool tilesEnabled = true;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _fitted = false;

  List<TrackPoint> get _allPoints =>
      widget.segments.expand((s) => s).toList(growable: false);

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;

    if (widget.follow) {
      final last = _lastPoint();
      if (last != null) {
        _controller.move(LatLng(last.lat, last.lng), _controller.camera.zoom);
      }
    } else if (widget.fitToRoute && !_fitted) {
      _fit();
    }
  }

  TrackPoint? _lastPoint() {
    for (final seg in widget.segments.reversed) {
      if (seg.isNotEmpty) return seg.last;
    }
    return null;
  }

  void _fit() {
    final pts = _allPoints;
    if (pts.length < 2) return;
    _fitted = true;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          pts.map((p) => LatLng(p.lat, p.lng)).toList(),
        ),
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _lastPoint();
    final first = _allPoints.isEmpty ? null : _allPoints.first;

    final center = last != null
        ? LatLng(last.lat, last.lng)
        : widget.initialCenter ?? const LatLng(37.5665, 126.9780); // 서울시청

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onMapReady: () {
          _ready = true;
          if (widget.fitToRoute) _fit();
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        if (RouteMap.tilesEnabled)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.petwalk.app',
            maxNativeZoom: 19,
          ),
        PolylineLayer(
          polylines: [
            for (final seg in widget.segments)
              if (seg.length >= 2)
                Polyline(
                  points: seg.map((p) => LatLng(p.lat, p.lng)).toList(),
                  color: scheme.primary,
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
          ],
        ),
        if (widget.showEndpoints && first != null)
          MarkerLayer(
            markers: [
              _dot(LatLng(first.lat, first.lng), Colors.green.shade600),
              if (last != null && last != first)
                _dot(LatLng(last.lat, last.lng), scheme.primary),
            ],
          ),
        // OSM 타일 사용 조건상 출처 표기가 필요하다.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Marker _dot(LatLng at, Color color) => Marker(
        point: at,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      );
}
