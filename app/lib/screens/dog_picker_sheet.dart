import 'package:flutter/material.dart';

import '../models/dog.dart';
import '../models/walk_goal.dart';
import '../utils/format.dart';

/// 산책을 시작하기 전에 함께 나갈 아이를 고른다.
///
/// 한 마리만 등록돼 있으면 이 화면을 띄우지 않는다. 매번 같은 선택을
/// 시키는 건 방해일 뿐이다.
class DogPickerSheet extends StatefulWidget {
  const DogPickerSheet({super.key, required this.dogs});

  final List<Dog> dogs;

  @override
  State<DogPickerSheet> createState() => _DogPickerSheetState();
}

class _DogPickerSheetState extends State<DogPickerSheet> {
  late final Set<int> _selected = {
    // 기본값은 전부 선택. 다견 가정도 대개 다 같이 나간다.
    for (final d in widget.dogs) d.id!,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen =
        widget.dogs.where((d) => _selected.contains(d.id)).toList();
    final goal = WalkGoal.forDogs(chosen);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('누구와 나가시나요?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final dog in widget.dogs)
                    CheckboxListTile(
                      value: _selected.contains(dog.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(dog.id!);
                        } else {
                          _selected.remove(dog.id);
                        }
                      }),
                      title: Text(dog.name),
                      subtitle: Text([
                        if (dog.breed != null) dog.breed!,
                        dog.ageText,
                      ].join(' · ')),
                      secondary: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: const Icon(Icons.pets, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            if (chosen.isNotEmpty) ...[
              const Divider(),
              Text(
                '오늘 권장 ${Fmt.distance(goal.dailyDistanceM)} · '
                '${goal.dailyMinutes}분',
                style: theme.textTheme.bodyMedium,
              ),
              if (chosen.length > 1)
                Text(
                  '여러 마리가 함께 나갈 때는 가장 체력이 약한 아이에 맞췄어요.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              for (final c in goal.cautions) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(c, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <int>[]),
                    child: const Text('선택 없이 시작'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected.toList()),
                    child: const Text('산책 시작'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
