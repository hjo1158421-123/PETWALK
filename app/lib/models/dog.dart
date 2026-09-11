import '../data/breed_catalog.dart';

/// 몸집. 권장 운동량과 노령 기준이 크기마다 다르다.
enum DogSize {
  small('소형견'),
  medium('중형견'),
  large('대형견');

  const DogSize(this.label);
  final String label;
}

/// 다른 개·사람에 대한 태도.
/// 추천 단계에서 혼잡한 길을 피할지 판단하는 데 쓴다.
enum Sociability {
  shy('낯을 가려요'),
  neutral('보통이에요'),
  friendly('사교적이에요');

  const Sociability(this.label);
  final String label;
}

/// 활동량. 권장 산책량의 배율이 된다.
enum EnergyLevel {
  low('차분해요'),
  medium('보통이에요'),
  high('활발해요');

  const EnergyLevel(this.label);
  final String label;
}

/// 반려견 프로필.
///
/// 여기 담긴 값들은 산책 기록을 보기 좋게 하는 용도만이 아니다.
/// 산책로 추천이 붙을 때 가중치를 정하는 입력이 된다 — 단두종이면 여름
/// 시간대를 막고, 노령견이면 경사 가중치를 올리는 식이다.
class Dog {
  final int? id;
  final String name;
  final String? breed;

  /// 생년월 (YYYYMM). 정확한 날짜를 모르는 경우가 대부분이라 월까지만 받는다.
  final int? birthYm;

  final double? weightKg;
  final DogSize size;
  final Sociability sociability;
  final EnergyLevel energy;

  /// 단두종(코가 짧은 견종) 여부.
  /// 호흡이 불리해서 더위와 긴 산책에 취약하다. 견종에서 자동으로 채우되
  /// 믹스견 등을 위해 직접 바꿀 수 있게 둔다.
  final bool brachycephalic;

  final bool isActive;
  final DateTime createdAt;

  const Dog({
    this.id,
    required this.name,
    this.breed,
    this.birthYm,
    this.weightKg,
    this.size = DogSize.small,
    this.sociability = Sociability.neutral,
    this.energy = EnergyLevel.medium,
    this.brachycephalic = false,
    this.isActive = true,
    required this.createdAt,
  });

  /// 견종을 고르면 크기·단두종·활동량을 카탈로그에서 채워 준다.
  factory Dog.fromBreed(String name, String breedName, {DateTime? createdAt}) {
    final breed = BreedCatalog.find(breedName);
    return Dog(
      name: name,
      breed: breedName,
      size: breed?.size ?? DogSize.small,
      energy: breed?.energy ?? EnergyLevel.medium,
      brachycephalic: breed?.brachycephalic ?? false,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  int? get ageMonths {
    final ym = birthYm;
    if (ym == null) return null;
    final year = ym ~/ 100;
    final month = ym % 100;
    if (month < 1 || month > 12) return null;
    final now = DateTime.now();
    final months = (now.year - year) * 12 + (now.month - month);
    return months < 0 ? 0 : months;
  }

  String get ageText {
    final m = ageMonths;
    if (m == null) return '나이 모름';
    if (m < 12) return '$m개월';
    final years = m ~/ 12;
    final rest = m % 12;
    return rest == 0 ? '$years살' : '$years살 $rest개월';
  }

  bool get isPuppy => (ageMonths ?? 999) < 12;

  /// 노령 기준은 몸집이 클수록 빨리 온다.
  bool get isSenior {
    final m = ageMonths;
    if (m == null) return false;
    final threshold = switch (size) {
      DogSize.small => 10 * 12,
      DogSize.medium => 8 * 12,
      DogSize.large => 6 * 12,
    };
    return m >= threshold;
  }

  Dog copyWith({
    int? id,
    String? name,
    String? breed,
    int? birthYm,
    double? weightKg,
    DogSize? size,
    Sociability? sociability,
    EnergyLevel? energy,
    bool? brachycephalic,
    bool? isActive,
  }) =>
      Dog(
        id: id ?? this.id,
        name: name ?? this.name,
        breed: breed ?? this.breed,
        birthYm: birthYm ?? this.birthYm,
        weightKg: weightKg ?? this.weightKg,
        size: size ?? this.size,
        sociability: sociability ?? this.sociability,
        energy: energy ?? this.energy,
        brachycephalic: brachycephalic ?? this.brachycephalic,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'breed': breed,
        'birth_ym': birthYm,
        'weight_kg': weightKg,
        'size': size.name,
        'sociability': sociability.name,
        'energy': energy.name,
        'brachycephalic': brachycephalic ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Dog.fromMap(Map<String, Object?> m) => Dog(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        breed: m['breed'] as String?,
        birthYm: m['birth_ym'] as int?,
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        size: _enumByName(DogSize.values, m['size'] as String?, DogSize.small),
        sociability: _enumByName(
            Sociability.values, m['sociability'] as String?, Sociability.neutral),
        energy: _enumByName(
            EnergyLevel.values, m['energy'] as String?, EnergyLevel.medium),
        brachycephalic: (m['brachycephalic'] as int? ?? 0) == 1,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['created_at'] as int?) ?? 0),
      );
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
