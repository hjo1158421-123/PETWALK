import 'package:latlong2/latlong.dart';

import '../services/geo.dart';

/// 추천 엔진이 다루는 최소 단위. OSM 의 way 하나를 약 100m 씩 잘라 만든다.
///
/// 산책로 DB를 통째로 구할 수는 없지만, 길을 세그먼트로 쪼개고 세그먼트마다
/// 점수를 매기면 "산책로로 등록된 적 없는 길"도 추천에 쓸 수 있다.
/// 자세한 설계는 docs/추천-설계.md 참조.
class RouteSegment {
  const RouteSegment({
    required this.id,
    required this.points,
    required this.highway,
    this.surface,
    this.osmName,
    this.sidewalk,
    this.nearGreenery = false,
  });

  /// `<OSM way id>#<분할 순번>`. 같은 way 에서 나온 세그먼트를 구분한다.
  final String id;

  /// 세그먼트를 이루는 좌표. 최소 2개.
  final List<LatLng> points;

  /// OSM `highway` 태그. `footway`, `path`, `residential` 등.
  final String highway;

  /// OSM `surface` 태그. 없으면 알 수 없음 — 점수화에서 중간값으로 취급한다.
  final String? surface;

  final String? osmName;

  /// OSM `sidewalk` 태그(both/left/right/none/separate). 차도 분리도 판단에 쓴다.
  final String? sidewalk;

  /// 300m 이내에 공원·가로수·숲이 있는지. Overpass 로 함께 받아 채운다.
  final bool nearGreenery;

  LatLng get start => points.first;
  LatLng get end => points.last;

  /// 세그먼트 길이(m). 좌표 사이 거리를 그대로 누적한다 — 곡선 도로라도
  /// 세그먼트 하나는 100m 안팎이라 직선 근사 오차가 무시할 만하다.
  double get lengthM {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += haversineM(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return sum;
  }

  /// 차도 전용 도로인지. 하드 필터에서 걸러낸다.
  ///
  /// 설계 문서의 "보도가 없는 차도, 자전거 전용도로" 배제 규칙 —
  /// 자전거 전용(`cycleway`)은 반려견과 함께 걷기에 위험하고, 차량
  /// 전용 도로는 애초에 보행이 불가능하거나 불법이다.
  bool get isCarOrCycleOnly => const {
        'motorway',
        'motorway_link',
        'trunk',
        'trunk_link',
        'primary',
        'primary_link',
        'cycleway',
      }.contains(highway);

  RouteSegment copyWith({bool? nearGreenery}) => RouteSegment(
        id: id,
        points: points,
        highway: highway,
        surface: surface,
        osmName: osmName,
        sidewalk: sidewalk,
        nearGreenery: nearGreenery ?? this.nearGreenery,
      );

  /// 좌표 순서를 뒤집은 세그먼트. 코스 생성이 이 세그먼트를 반대 방향
  /// (끝→시작)으로 지나갈 때, 지도에 그릴 폴리라인이 끊기지 않게 쓴다.
  RouteSegment get reversed => RouteSegment(
        id: id,
        points: points.reversed.toList(),
        highway: highway,
        surface: surface,
        osmName: osmName,
        sidewalk: sidewalk,
        nearGreenery: nearGreenery,
      );
}
