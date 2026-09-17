import 'package:flutter/material.dart';

import '../data/breed_catalog.dart';
import '../models/dog.dart';
import '../models/walk_goal.dart';
import '../services/dog_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// 반려견 프로필을 새로 만들거나 고친다.
class DogEditScreen extends StatefulWidget {
  const DogEditScreen({super.key, this.dog});

  /// 비어 있으면 새로 등록하는 화면이 된다.
  final Dog? dog;

  @override
  State<DogEditScreen> createState() => _DogEditScreenState();
}

class _DogEditScreenState extends State<DogEditScreen> {
  final _repo = DogRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _weight;

  String? _breed;
  int? _birthYm;
  late DogSize _size;
  late Sociability _sociability;
  late EnergyLevel _energy;
  late bool _brachycephalic;

  bool get _isNew => widget.dog == null;

  @override
  void initState() {
    super.initState();
    final d = widget.dog;
    _name = TextEditingController(text: d?.name ?? '');
    _weight = TextEditingController(
        text: d?.weightKg == null ? '' : d!.weightKg!.toString());
    _breed = d?.breed;
    _birthYm = d?.birthYm;
    _size = d?.size ?? DogSize.small;
    _sociability = d?.sociability ?? Sociability.neutral;
    _energy = d?.energy ?? EnergyLevel.medium;
    _brachycephalic = d?.brachycephalic ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// 견종을 고르면 크기·활동량·단두종 여부를 채워 준다.
  /// 사용자가 직접 바꾼 값을 덮어쓰지 않도록, 견종을 새로 고를 때만 반영한다.
  void _applyBreed(String? name) {
    final breed = BreedCatalog.find(name);
    setState(() {
      _breed = name;
      if (breed != null) {
        _size = breed.size;
        _energy = breed.energy;
        _brachycephalic = breed.brachycephalic;
      }
    });
  }

  Dog _build() {
    final base = widget.dog;
    return Dog(
      id: base?.id,
      name: _name.text.trim(),
      breed: _breed,
      birthYm: _birthYm,
      weightKg: double.tryParse(_weight.text.trim()),
      size: _size,
      sociability: _sociability,
      energy: _energy,
      brachycephalic: _brachycephalic,
      isActive: base?.isActive ?? true,
      createdAt: base?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dog = _build();
    if (_isNew) {
      await _repo.insertDog(dog);
    } else {
      await _repo.updateDog(dog);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = WalkGoal.forDog(_build());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '반려견 등록' : '프로필 수정'),
        actions: [
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예) 콩이',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요' : null,
            ),
            const SizedBox(height: 20),

            _BreedField(value: _breed, onChanged: _applyBreed),
            const SizedBox(height: 20),

            _BirthField(
              value: _birthYm,
              onChanged: (v) => setState(() => _birthYm = v),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _weight,
              decoration: const InputDecoration(
                labelText: '체중 (kg)',
                hintText: '예) 4.2',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return '숫자로 입력해 주세요';
                if (parsed <= 0 || parsed > 120) return '체중을 다시 확인해 주세요';
                return null;
              },
            ),
            const SizedBox(height: 24),

            _ChoiceRow<DogSize>(
              label: '몸집',
              values: DogSize.values,
              selected: _size,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _size = v),
            ),
            const SizedBox(height: 16),

            _ChoiceRow<EnergyLevel>(
              label: '활동량',
              values: EnergyLevel.values,
              selected: _energy,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _energy = v),
            ),
            const SizedBox(height: 16),

            _ChoiceRow<Sociability>(
              label: '다른 강아지를 만나면',
              values: Sociability.values,
              selected: _sociability,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _sociability = v),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _brachycephalic,
              onChanged: (v) => setState(() => _brachycephalic = v),
              title: const Text('코가 짧은 견종이에요'),
              subtitle: const Text('퍼그, 프렌치 불독, 시츄처럼 주둥이가 납작한 아이들이에요'),
            ),

            const SizedBox(height: 24),
            _GoalPreview(goal: preview),
          ],
        ),
      ),
    );
  }
}

/// 견종 선택. 목록에서 고르거나 직접 입력할 수 있다.
class _BreedField extends StatelessWidget {
  const _BreedField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _BreedPicker(),
        );
        if (picked != null) onChanged(picked.isEmpty ? null : picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '견종',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? '선택 안 함',
          style: value == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}

class _BreedPicker extends StatefulWidget {
  const _BreedPicker();

  @override
  State<_BreedPicker> createState() => _BreedPickerState();
}

class _BreedPickerState extends State<_BreedPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final results = BreedCatalog.search(_query);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '견종 검색 (예: 말티즈)',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (_query.trim().isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text('"${_query.trim()}" 직접 입력'),
                      onTap: () => Navigator.pop(context, _query.trim()),
                    ),
                  for (final b in results)
                    ListTile(
                      title: Text(b.name),
                      subtitle: Text(
                        '${b.size.label} · ${b.energy.label}'
                        '${b.brachycephalic ? ' · 단두종' : ''}',
                      ),
                      onTap: () => Navigator.pop(context, b.name),
                    ),
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('선택 안 함'),
                    onTap: () => Navigator.pop(context, ''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 생년월 선택. 정확한 날짜를 모르는 경우가 많아 연·월까지만 받는다.
class _BirthField extends StatelessWidget {
  const _BirthField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = value == null ? null : value! ~/ 100;
    final month = value == null ? null : value! % 100;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: year,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '태어난 해'),
            items: [
              for (var y = now.year; y >= now.year - 25; y--)
                DropdownMenuItem(value: y, child: Text('$y년')),
            ],
            onChanged: (y) =>
                onChanged(y == null ? null : y * 100 + (month ?? 1)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            initialValue: month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '월'),
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text('$m월')),
            ],
            onChanged: (m) => onChanged(
                m == null ? null : (year ?? now.year) * 100 + m),
          ),
        ),
      ],
    );
  }
}

/// 선택지를 가로로 늘어놓는 공통 위젯.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(labelOf(v)),
                selected: v == selected,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
      ],
    );
  }
}

/// 입력한 내용으로 계산한 하루 권장 산책량. 입력하면서 바로 보인다.
class _GoalPreview extends StatelessWidget {
  const _GoalPreview({required this.goal});

  final WalkGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('하루 권장 산책량', style: theme.textTheme.titleSmall),
                if (goal.hasBreedEvidence) ...[
                  const SizedBox(width: 8),
                  const _EvidenceBadge(),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _stat(context, '시간', '${goal.dailyMinutes}분'),
                ),
                Expanded(
                  child: _stat(context, '나눠서',
                      '${goal.sessionMinutes}분씩 ${goal.sessionsPerDay}번'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 거리는 목표가 아니라 환산 참고치다. 목표로 오해하지 않도록
            // 작게, "약"을 붙여 보여 준다.
            Text(
              '보통 걸음이면 약 ${Fmt.distance(goal.dailyDistanceM)} 정도예요',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            for (final c in goal.cautions) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.text,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(height: 1.4)),
                        const SizedBox(height: 2),
                        Text(
                          c.source,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              goal.hasBreedEvidence
                  ? '이 견종에 대해 UK 켄넬클럽이 공식으로 권장하는 운동 시간이에요. '
                      '건강한 아이를 전제하며, 관절이나 심장에 문제가 있다면 수의사와 '
                      '상의한 기준을 따라 주세요.'
                  : '이 견종의 실측 자료가 없어 몸집만 보고 추정한 일반 기준이에요. '
                      '건강한 아이를 전제하며, 관절이나 심장에 문제가 있다면 수의사와 '
                      '상의한 기준을 따라 주세요.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final tokens = PetWalkTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: tokens.display.copyWith(fontSize: 26)),
        const SizedBox(height: 3),
        Text(label, style: tokens.caption),
      ],
    );
  }
}

/// "이 숫자는 견종 실측 자료에서 왔다"는 걸 한눈에 보여 주는 작은 배지.
///
/// `WalkGoal.hasBreedEvidence` 가 true 일 때만 나타난다. 몸집만 보고
/// 추정한 값과 실측 자료를 눈으로 구분할 수 있어야, 사용자가 "이 숫자를
/// 얼마나 믿어도 되는지" 판단할 수 있다.
class _EvidenceBadge extends StatelessWidget {
  const _EvidenceBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified,
              size: 13, color: scheme.onSecondaryContainer),
          const SizedBox(width: 3),
          Text(
            '켄넬클럽 실측 기준',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
