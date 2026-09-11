import 'dart:async';

import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/walk_goal.dart';
import '../services/dog_repository.dart';
import '../utils/format.dart';
import 'dog_edit_screen.dart';

/// 등록된 반려견 목록. 프로필을 추가·수정하고 아이별 산책 통계를 본다.
class DogsScreen extends StatefulWidget {
  const DogsScreen({super.key});

  @override
  State<DogsScreen> createState() => DogsScreenState();
}

class DogsScreenState extends State<DogsScreen> {
  final _repo = DogRepository();

  List<Dog> _dogs = const [];
  final Map<int, ({int count, double distanceM, int totalSec})> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    final dogs = await _repo.listDogs();
    final since = DateTime.now().subtract(const Duration(days: 7));
    final stats = <int, ({int count, double distanceM, int totalSec})>{};
    for (final d in dogs) {
      stats[d.id!] = await _repo.statsFor(d.id!, since: since);
    }
    if (!mounted) return;
    setState(() {
      _dogs = dogs;
      _stats
        ..clear()
        ..addAll(stats);
      _loading = false;
    });
  }

  Future<void> _openEditor([Dog? dog]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DogEditScreen(dog: dog)),
    );
    if (changed == true) await reload();
  }

  Future<void> _confirmRemove(Dog dog) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${dog.name}를 목록에서 뺄까요?'),
        content: const Text(
          '지난 산책 기록은 그대로 남아요. 통계가 어긋나지 않도록 기록은 지우지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('빼기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deactivateDog(dog.id!);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('우리 아이')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('반려견 등록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dogs.isEmpty
              ? _empty(context)
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _dogs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _DogCard(
                      dog: _dogs[i],
                      weekly: _stats[_dogs[i].id],
                      onEdit: () => _openEditor(_dogs[i]),
                      onRemove: () => _confirmRemove(_dogs[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 화면이 낮으면(가로 모드나 작은 창) 넘치므로 스크롤 가능하게 둔다.
    return SingleChildScrollView(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              '아직 등록된 아이가 없어요.\n'
              '견종과 나이를 알려주면 산책량을 맞춰 계산해 드려요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DogCard extends StatelessWidget {
  const _DogCard({
    required this.dog,
    required this.weekly,
    required this.onEdit,
    required this.onRemove,
  });

  final Dog dog;
  final ({int count, double distanceM, int totalSec})? weekly;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = WalkGoal.forDog(dog);

    // 최근 7일 실적을 하루 권장량 x 7 과 견준다.
    final walked = weekly?.distanceM ?? 0;
    final target = goal.dailyDistanceM * 7;
    final progress = target <= 0 ? 0.0 : (walked / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: const Icon(Icons.pets),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dog.name, style: theme.textTheme.titleMedium),
                    Text(
                      [
                        if (dog.breed != null) dog.breed!,
                        dog.ageText,
                        if (dog.weightKg != null) '${dog.weightKg}kg',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '수정',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '목록에서 빼기',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '이번 주 ${Fmt.distance(walked)} / '
                  '목표 ${Fmt.distance(target)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(context, dog.size.label),
              _tag(context, dog.energy.label),
              _tag(context, dog.sociability.label),
              if (dog.brachycephalic) _tag(context, '단두종', warn: true),
              if (dog.isSenior) _tag(context, '노령견', warn: true),
              if (dog.isPuppy) _tag(context, '자견', warn: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, {bool warn = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warn ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
