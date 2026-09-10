import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/track_point.dart';
import '../models/walk.dart';
import '../services/walk_repository.dart';
import '../utils/format.dart';
import '../widgets/route_map.dart';
import 'walk_detail_screen.dart';

/// 같은 길로 묶인 산책들을 한 곳에서 본다.
/// "이 코스를 몇 번 걸었고, 갈수록 어떻게 달라졌는지"가 이 화면의 핵심이다.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final int courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _repo = WalkRepository();

  Course? _course;
  List<Walk> _walks = const [];
  List<List<TrackPoint>> _segments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final course = await _repo.findCourse(widget.courseId);
    final walks = await _repo.walksOfCourse(widget.courseId);

    // 대표 경로는 가장 최근 산책으로 그린다.
    var segments = const <List<TrackPoint>>[];
    if (walks.isNotEmpty) {
      final points = await _repo.pointsFor(walks.first.id!);
      if (points.isNotEmpty) segments = [points];
    }

    if (!mounted) return;
    setState(() {
      _course = course;
      _walks = walks;
      _segments = segments;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _course?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코스 이름'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예) 한강 산책로'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await _repo.renameCourse(widget.courseId, name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;

    return Scaffold(
      appBar: AppBar(
        title: Text(course?.name ?? '코스'),
        actions: [
          if (course != null)
            IconButton(
              onPressed: _rename,
              icon: const Icon(Icons.edit_outlined),
              tooltip: '이름 변경',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : course == null
              ? const Center(child: Text('코스를 찾을 수 없어요.'))
              : ListView(
                  children: [
                    SizedBox(
                      height: 280,
                      child: RouteMap(segments: _segments, fitToRoute: true),
                    ),
                    _summary(context, course),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('이 코스로 걸은 기록',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final w in _walks) _walkTile(context, w),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }

  Widget _summary(BuildContext context, Course course) {
    final fastest = _walks.isEmpty
        ? null
        : _walks.reduce((a, b) => a.avgSpeedMps > b.avgSpeedMps ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(context, '걸은 횟수', '${course.walkCount}회'),
          _cell(context, '평균 거리', Fmt.distance(course.distanceM)),
          _cell(
            context,
            '최고 페이스',
            fastest == null ? '-' : Fmt.pace(fastest.avgSpeedMps),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _walkTile(BuildContext context, Walk w) {
    return ListTile(
      leading: const Icon(Icons.pets, size: 20),
      title: Text(Fmt.dateTime(w.startedAt)),
      subtitle: Text(
        '${Fmt.distance(w.distanceM)} · ${Fmt.duration(w.totalSec)} · '
        '페이스 ${Fmt.pace(w.avgSpeedMps)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WalkDetailScreen(walkId: w.id!),
        ));
        await _load();
      },
    );
  }
}
