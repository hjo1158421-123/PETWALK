import 'package:latlong2/latlong.dart';

import '../models/recommended_course.dart';
import '../models/route_segment.dart';
import 'geo.dart';
import 'segment_scorer.dart';

/// 세그먼트 그래프에서 순환 코스를 찾는다.
///
/// **완전한 최적해가 아니다.** "출발점에서 시작해 목표 거리만큼 걷고
/// 다시 돌아오는, 점수가 좋은 경로"를 찾는 문제는 순회 문제(orienteering
/// problem) 계열이라 정확히 풀려면 pgRouting 같은 전문 도구가 필요하다
/// (docs/추천-설계.md 의 최종 그림). 지금은 백엔드 없이 앱 안에서 바로
/// 확인해 보기 위한 프로토타입이라, 완벽한 답 대신 **빠르게 나오는
/// 그럴듯한 답 하나**를 목표로 한다:
///
/// 1. 시작점에서 각 노드까지 "점수가 좋은 길일수록 짧게 느껴지는" cost
///    (`거리 ÷ 적합도`)로 최단 경로 트리를 만든다(Dijkstra)
/// 2. 목표 거리의 절반에 가장 가까운 노드를 반환점으로 고른다
/// 3. 반환점에서 시작점까지, 방금 지나온 길은 피해서 다시 최단 경로를
///    찾는다 — 성공하면 순환 코스, 실패하면(막다른 길이라 대안이 없으면)
///    왔던 길을 그대로 되짚어 왕복 코스로 낸다
class RouteRecommender {
  const RouteRecommender._();

  /// [segments] 중 [start] 근처를 지나면서 [targetDistanceM] 에 가까운
  /// 순환 코스를 찾는다. 적합한 경로가 없으면 null.
  ///
  /// [elevations] 는 [coordKey] → 고도(m) 맵이다(`ElevationService` 가
  /// 채운다). 없어도 동작하지만, 그러면 경사 지표가 전부 중간값(0.5)으로
  /// 빠져 실질적으로 4개 지표(노면·분리도·그늘·???)만 반영된다.
  ///
  /// [toleranceRatio] 는 반환점을 목표 절반 거리의 ±35% 안에서 고른다는
  /// 뜻이다. 너무 좁히면(예: ±10%) 그래프가 성긴 지역에서 후보가 아예
  /// 없어 추천 자체가 실패하는 일이 잦다 — **근거 없음**, 실사용
  /// 데이터가 쌓이면 조정할 값이다.
  static RecommendedCourse? recommend({
    required List<RouteSegment> segments,
    required LatLng start,
    required double targetDistanceM,
    Map<String, double> elevations = const {},
    double toleranceRatio = 0.35,
  }) {
    final usable = [
      for (final s in segments)
        if (!s.isCarOrCycleOnly && s.points.length >= 2) s,
    ];
    if (usable.isEmpty || targetDistanceM <= 0) return null;

    final graph = _buildGraph(usable, elevations);
    if (graph.isEmpty) return null;

    final startKey = _nearestNodeKey(graph, start);
    if (startKey == null) return null;

    final outbound = _dijkstra(graph, startKey, avoid: const {});
    final turnaround = _pickTurnaround(
      outbound,
      startKey: startKey,
      halfTarget: targetDistanceM / 2,
      toleranceRatio: toleranceRatio,
    );
    if (turnaround == null) return null;

    final outPath = _reconstructPath(outbound, turnaround);
    if (outPath.isEmpty) return null;

    final usedIds = {for (final e in outPath) e.segment.id};
    final inbound = _dijkstra(graph, turnaround, avoid: usedIds);

    final inPath = inbound.distanceM.containsKey(startKey)
        ? _reconstructPath(inbound, startKey)
        : [for (final e in outPath.reversed) e.flipped];

    return _buildCourse([...outPath, ...inPath]);
  }

  // ----------------------------------------------------------- 그래프 구성

  static Map<String, List<_Edge>> _buildGraph(
    List<RouteSegment> segs,
    Map<String, double> elevations,
  ) {
    final graph = <String, List<_Edge>>{};
    for (final seg in segs) {
      final fromKey = coordKey(seg.start.latitude, seg.start.longitude);
      final toKey = coordKey(seg.end.latitude, seg.end.longitude);
      if (fromKey == toKey) continue; // 시작=끝인 고리형 세그먼트는 제외

      final gradient = gradientPercentOf(
        seg,
        startElevationM: elevations[fromKey],
        endElevationM: elevations[toKey],
      );

      // cost 가 0이나 음수로 가면 안 되니 점수 하한을 둔다. 점수가
      // 극단적으로 낮은 세그먼트도 "매우 비싸다"일 뿐 "못 지나간다"는
      // 아니어야 한다 — 그 길밖에 없을 때도 루프는 만들어져야 한다.
      final score = SegmentScorer.score(seg, gradientPercent: gradient)
          .total
          .clamp(5, 100)
          .toDouble();
      final cost = seg.lengthM / (score / 100);

      graph.putIfAbsent(fromKey, () => []).add(_Edge(
            segment: seg,
            fromKey: fromKey,
            toKey: toKey,
            cost: cost,
            score: score,
            forward: true,
          ));
      graph.putIfAbsent(toKey, () => []).add(_Edge(
            segment: seg,
            fromKey: toKey,
            toKey: fromKey,
            cost: cost,
            score: score,
            forward: false,
          ));
    }
    return graph;
  }

  static String? _nearestNodeKey(
      Map<String, List<_Edge>> graph, LatLng point) {
    String? best;
    var bestDist = double.infinity;
    for (final key in graph.keys) {
      final comma = key.indexOf(',');
      final lat = double.parse(key.substring(0, comma));
      final lng = double.parse(key.substring(comma + 1));
      final d = haversineM(point.latitude, point.longitude, lat, lng);
      if (d < bestDist) {
        bestDist = d;
        best = key;
      }
    }
    return best;
  }

  // --------------------------------------------------------------- 탐색

  /// [avoid] 의 세그먼트는 아예 막지 않고 아주 비싸게만 만든다. 완전히
  /// 막으면 그 길밖에 없는 경우 순환 코스를 영영 못 만든다 — 비싸게 해
  /// 두면 "그래도 대안이 없을 때"는 여전히 선택된다.
  static _DijkstraResult _dijkstra(
    Map<String, List<_Edge>> graph,
    String startKey, {
    required Set<String> avoid,
  }) {
    final cost = <String, double>{startKey: 0};
    final distanceM = <String, double>{startKey: 0};
    final prevEdge = <String, _Edge>{};
    final visited = <String>{};

    while (true) {
      String? u;
      var best = double.infinity;
      for (final entry in cost.entries) {
        if (visited.contains(entry.key)) continue;
        if (entry.value < best) {
          best = entry.value;
          u = entry.key;
        }
      }
      if (u == null) break;
      visited.add(u);

      for (final edge in graph[u] ?? const <_Edge>[]) {
        final penalty = avoid.contains(edge.segment.id) ? edge.cost * 50 : 0.0;
        final altCost = cost[u]! + edge.cost + penalty;
        if (altCost < (cost[edge.toKey] ?? double.infinity)) {
          cost[edge.toKey] = altCost;
          distanceM[edge.toKey] = distanceM[u]! + edge.segment.lengthM;
          prevEdge[edge.toKey] = edge;
        }
      }
    }

    return _DijkstraResult(distanceM: distanceM, prevEdge: prevEdge);
  }

  static String? _pickTurnaround(
    _DijkstraResult result, {
    required String startKey,
    required double halfTarget,
    required double toleranceRatio,
  }) {
    final minOk = halfTarget * (1 - toleranceRatio);
    final maxOk = halfTarget * (1 + toleranceRatio);

    String? best;
    var bestDiff = double.infinity;
    for (final entry in result.distanceM.entries) {
      if (entry.key == startKey) continue;
      final d = entry.value;
      if (d < minOk || d > maxOk) continue;
      final diff = (d - halfTarget).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = entry.key;
      }
    }
    return best;
  }

  static List<_Edge> _reconstructPath(_DijkstraResult result, String target) {
    final path = <_Edge>[];
    var cur = target;
    while (result.prevEdge.containsKey(cur)) {
      final edge = result.prevEdge[cur]!;
      path.add(edge);
      cur = edge.fromKey;
    }
    return path.reversed.toList();
  }

  static RecommendedCourse _buildCourse(List<_Edge> edges) {
    final segments = [for (final e in edges) e.orientedSegment];
    final totalLen = segments.fold<double>(0, (sum, s) => sum + s.lengthM);

    // 그래프 구성 때 이미 계산해 둔 score 를 재사용한다 — 여기서 다시
    // SegmentScorer.score() 를 부르면 경사 지표가 빠진 채(고도 정보가
    // 이 스코프엔 없으므로) 재계산되어 그래프가 고른 경로와 다른 점수를
    // 보여주게 된다.
    var weightedScore = 0.0;
    for (final e in edges) {
      weightedScore += e.score * e.segment.lengthM;
    }

    return RecommendedCourse(
      segments: segments,
      distanceM: totalLen,
      averageScore: totalLen > 0 ? weightedScore / totalLen : 0,
    );
  }
}

class _Edge {
  const _Edge({
    required this.segment,
    required this.fromKey,
    required this.toKey,
    required this.cost,
    required this.score,
    required this.forward,
  });

  final RouteSegment segment;
  final String fromKey;
  final String toKey;
  final double cost;

  /// 0~100. 그래프 구성 시 계산해 둔 [SegmentScoreBreakdown.total] —
  /// 코스를 최종 조립할 때 다시 계산하지 않고 재사용한다.
  final double score;

  /// true 면 `segment.points` 그대로, false 면 뒤집어야 [fromKey] →
  /// [toKey] 방향과 맞는다.
  final bool forward;

  RouteSegment get orientedSegment => forward ? segment : segment.reversed;

  _Edge get flipped => _Edge(
        segment: segment,
        fromKey: toKey,
        toKey: fromKey,
        cost: cost,
        score: score,
        forward: !forward,
      );
}

class _DijkstraResult {
  const _DijkstraResult({required this.distanceM, required this.prevEdge});

  final Map<String, double> distanceM;
  final Map<String, _Edge> prevEdge;
}
