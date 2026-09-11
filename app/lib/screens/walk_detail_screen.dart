import 'dart:async';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/track_point.dart';
import '../models/walk.dart';
import '../models/dog.dart';
import '../services/dog_repository.dart';
import '../services/walk_repository.dart';
import '../utils/format.dart';
import '../widgets/route_map.dart';

class WalkDetailScreen extends StatefulWidget {
  const WalkDetailScreen({
    super.key,
    required this.walkId,
    this.justFinished = false,
  });

  final int walkId;
  final bool justFinished;

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  final _repo = WalkRepository();
  final _dogRepo = DogRepository();

  Walk? _walk;
  Course? _course;
  int _courseOrder = 0;
  List<List<TrackPoint>> _segments = const [];
  List<Dog> _dogs = const [];
  bool _loading = true;

  /// 이 시간 이상 끊긴 구간은 선을 잇지 않는다.
  /// 일시정지든 터널에서 신호가 끊긴 거든, 지나지 않은 길을 직선으로
  /// 그어 버리면 거리도 경로도 거짓말이 된다.
  static const _segmentGap = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final walk = await _repo.findWalk(widget.walkId);
    final points = await _repo.pointsFor(widget.walkId);
    final dogs = await _dogRepo.dogsForWalk(widget.walkId);

    Course? course;
    var order = 0;
    if (walk?.courseId != null) {
      course = await _repo.findCourse(walk!.courseId!);
      final walks = await _repo.walksOfCourse(walk.courseId!);
      // 오래된 순으로 몇 번째 산책인지
      order = walks.length -
          walks.indexWhere((w) => w.id == widget.walkId);
    }

    if (!mounted) return;
    setState(() {
      _walk = walk;
      _course = course;
      _courseOrder = order;
      _dogs = dogs;
      _segments = _splitSegments(points);
      _loading = false;
    });
  }

  static List<List<TrackPoint>> _splitSegments(List<TrackPoint> points) {
    if (points.isEmpty) return const [];
    final segments = <List<TrackPoint>>[[]];
    for (var i = 0; i < points.length; i++) {
      if (i > 0 &&
          points[i].ts.difference(points[i - 1].ts) > _segmentGap) {
        segments.add([]);
      }
      segments.last.add(points[i]);
    }
    return segments;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 산책 기록을 삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _repo.deleteWalk(widget.walkId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final walk = _walk;

    return Scaffold(
      appBar: AppBar(
        title: Text(walk == null ? '산책' : Fmt.dateTime(walk.startedAt)),
        actions: [
          if (walk != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : walk == null
              ? const Center(child: Text('기록을 찾을 수 없어요.'))
              : ListView(
                  children: [
                    SizedBox(
                      height: 300,
                      child: RouteMap(segments: _segments, fitToRoute: true),
                    ),
                    if (widget.justFinished) _finishedBanner(context),
                    if (_dogs.isNotEmpty) _dogsCard(context),
                    if (_course != null) _courseCard(context, _course!),
                    _statsCard(context, walk),
                  ],
                ),
    );
  }

  Widget _finishedBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20),
          const SizedBox(width: 10),
          Text('산책이 기록되었어요',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }

  Widget _dogsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.pets),
        title: Text(_dogs.map((d) => d.name).join(', ')),
        subtitle: Text('${_dogs.length}마리와 함께 걸었어요'),
      ),
    );
  }

  Widget _courseCard(BuildContext context, Course course) {

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text(course.name),
        subtitle: Text('이 코스로 걷는 $_courseOrder번째 산책'),
      ),
    );
  }

  Widget _statsCard(BuildContext context, Walk walk) {
    final rows = <(String, String)>[
      ('거리', Fmt.distance(walk.distanceM)),
      ('전체 시간', Fmt.duration(walk.totalSec)),
      ('움직인 시간', Fmt.duration(walk.movingSec)),
      ('평균 페이스', Fmt.pace(walk.avgSpeedMps)),
      ('평균 속도', Fmt.speedKmh(walk.avgSpeedMps)),
      ('누적 상승', '${walk.elevGainM.round()} m'),
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final (label, value) in rows)
            ListTile(
              dense: true,
              title: Text(label),
              trailing: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: const Text('멈춰서 냄새 맡은 비율'),
            subtitle: const Text('높을수록 강아지가 여유롭게 탐색한 산책이에요'),
            trailing: Text(
              Fmt.percent(walk.sniffRatio),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
