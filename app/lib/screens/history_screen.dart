import 'dart:async';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/walk.dart';
import '../models/dog.dart';
import '../services/dog_repository.dart';
import '../services/walk_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'course_detail_screen.dart';
import 'walk_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _repo = WalkRepository();
  final _dogRepo = DogRepository();

  List<Walk> _walks = const [];
  List<Course> _courses = const [];
  Map<int, List<Dog>> _walkDogs = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    final walks = await _repo.listWalks();
    final courses = await _repo.listCourses();
    // 산책마다 따로 조회하면 N+1 이 된다. 한 번에 가져온다.
    final dogs = await _dogRepo.dogsForWalks([for (final w in walks) w.id!]);
    if (!mounted) return;
    setState(() {
      _walks = walks;
      _courses = courses;
      _walkDogs = dogs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('산책 이력'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '산책 기록'),
              Tab(text: '코스'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _Summary(walks: _walks),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _WalkList(
                          walks: _walks,
                          walkDogs: _walkDogs,
                          onChanged: reload,
                        ),
                        _CourseList(courses: _courses, onChanged: reload),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 최근 7일 요약. 이력 화면에 들어왔을 때 제일 먼저 궁금한 숫자들.
class _Summary extends StatelessWidget {
  const _Summary({required this.walks});

  final List<Walk> walks;

  @override
  Widget build(BuildContext context) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final recent = walks.where((w) => w.startedAt.isAfter(since)).toList();
    final totalM = recent.fold<double>(0, (sum, w) => sum + w.distanceM);
    final totalSec = recent.fold<int>(0, (sum, w) => sum + w.totalSec);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(context, 'LAST 7 DAYS', '최근 7일', '${recent.length}회'),
          _cell(context, 'DISTANCE', '총 거리', Fmt.distance(totalM)),
          _cell(context, 'TIME', '총 시간', Fmt.duration(totalSec)),
        ],
      ),
    );
  }

  /// 1b 는 캡션이 모노스페이스 대문자라 라벨을 두 벌 받는다.
  Widget _cell(
      BuildContext context, String monoLabel, String label, String value) {
    final tokens = PetWalkTokens.of(context);
    final minimal = tokens.variant == AppThemeVariant.minimal;

    return Column(
      crossAxisAlignment:
          minimal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(value, style: tokens.display.copyWith(fontSize: 24)),
        const SizedBox(height: 3),
        Text(minimal ? monoLabel : label, style: tokens.caption),
      ],
    );
  }
}

class _WalkList extends StatelessWidget {
  const _WalkList({
    required this.walks,
    required this.walkDogs,
    required this.onChanged,
  });

  final List<Walk> walks;
  final Map<int, List<Dog>> walkDogs;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (walks.isEmpty) {
      return const _Empty(
        icon: Icons.directions_walk,
        message: '아직 기록된 산책이 없어요.\n산책 탭에서 첫 산책을 시작해 보세요.',
      );
    }

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        itemCount: walks.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, i) {
          final w = walks[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.pets, size: 20),
            ),
            title: Text(
              Fmt.distance(w.distanceM),
              style: PetWalkTokens.of(context).display.copyWith(fontSize: 20),
            ),
            subtitle: Text([
              Fmt.duration(w.totalSec),
              '페이스 ${Fmt.pace(w.avgSpeedMps)}',
              if (walkDogs[w.id]?.isNotEmpty ?? false)
                walkDogs[w.id]!.map((d) => d.name).join(', '),
            ].join(' · ')),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.relativeDay(w.startedAt)),
                Text(
                  Fmt.dateTime(w.startedAt).split(' ').last,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WalkDetailScreen(walkId: w.id!),
              ));
              await onChanged();
            },
          );
        },
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.courses, required this.onChanged});

  final List<Course> courses;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _Empty(
        icon: Icons.route,
        message: '코스는 같은 길을 걸으면 자동으로 묶여요.\n산책을 몇 번 기록해 보세요.',
      );
    }

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        itemCount: courses.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, i) {
          final c = courses[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                '${c.walkCount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '평균 ${Fmt.distance(c.distanceM)}'
              '${c.lastWalkedAt == null ? '' : ' · 마지막 ${Fmt.relativeDay(c.lastWalkedAt!)}'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseDetailScreen(courseId: c.id!),
              ));
              await onChanged();
            },
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 화면이 낮으면 넘치므로 스크롤 가능하게 둔다.
    return SingleChildScrollView(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
