import '../models/dog.dart';

/// 견종 하나의 특성.
class Breed {
  const Breed(this.name, this.size, this.energy, {this.brachycephalic = false});

  final String name;
  final DogSize size;
  final EnergyLevel energy;

  /// 단두종(코가 짧은 견종).
  ///
  /// 기도가 짧아 체온 조절이 불리하다. 더위에 훨씬 취약하고 긴 산책도
  /// 버거워한다. 추천 단계에서 여름 낮 시간대를 막는 판단에 쓴다.
  final bool brachycephalic;
}

/// 국내에서 흔한 견종 목록.
///
/// 목적은 백과사전이 아니라 추천에 필요한 세 가지를 채우는 것이다:
/// 몸집, 활동량, 단두종 여부. 목록에 없으면 직접 입력하고 값을 고르면 된다.
class BreedCatalog {
  static const List<Breed> all = [
    // --- 소형견 ---
    Breed('말티즈', DogSize.small, EnergyLevel.medium),
    Breed('푸들(토이)', DogSize.small, EnergyLevel.high),
    Breed('포메라니안', DogSize.small, EnergyLevel.high),
    Breed('시츄', DogSize.small, EnergyLevel.low, brachycephalic: true),
    Breed('요크셔테리어', DogSize.small, EnergyLevel.high),
    Breed('치와와', DogSize.small, EnergyLevel.medium),
    Breed('비숑프리제', DogSize.small, EnergyLevel.high),
    Breed('닥스훈트', DogSize.small, EnergyLevel.medium),
    Breed('미니어처 핀셔', DogSize.small, EnergyLevel.high),
    Breed('파피용', DogSize.small, EnergyLevel.high),
    Breed('페키니즈', DogSize.small, EnergyLevel.low, brachycephalic: true),
    Breed('재패니즈 친', DogSize.small, EnergyLevel.low, brachycephalic: true),
    Breed('퍼그', DogSize.small, EnergyLevel.low, brachycephalic: true),
    Breed('보스턴테리어', DogSize.small, EnergyLevel.medium, brachycephalic: true),
    Breed('캐벌리어 킹 찰스 스파니엘', DogSize.small, EnergyLevel.medium,
        brachycephalic: true),
    Breed('잭 러셀 테리어', DogSize.small, EnergyLevel.high),
    Breed('웨스트 하이랜드 화이트테리어', DogSize.small, EnergyLevel.high),
    Breed('미니어처 슈나우저', DogSize.small, EnergyLevel.high),
    Breed('스피츠', DogSize.small, EnergyLevel.high),
    Breed('시고르자브종(믹스·소형)', DogSize.small, EnergyLevel.medium),

    // --- 중형견 ---
    Breed('웰시 코기', DogSize.medium, EnergyLevel.high),
    Breed('비글', DogSize.medium, EnergyLevel.high),
    Breed('시바견', DogSize.medium, EnergyLevel.high),
    Breed('진돗개', DogSize.medium, EnergyLevel.high),
    Breed('프렌치 불독', DogSize.medium, EnergyLevel.low, brachycephalic: true),
    Breed('불독', DogSize.medium, EnergyLevel.low, brachycephalic: true),
    Breed('코커 스파니엘', DogSize.medium, EnergyLevel.high),
    Breed('보더 콜리', DogSize.medium, EnergyLevel.high),
    Breed('푸들(미니어처)', DogSize.medium, EnergyLevel.high),
    Breed('삽살개', DogSize.medium, EnergyLevel.medium),
    Breed('바셋 하운드', DogSize.medium, EnergyLevel.low),
    Breed('휘핏', DogSize.medium, EnergyLevel.high),
    Breed('시고르자브종(믹스·중형)', DogSize.medium, EnergyLevel.medium),

    // --- 대형견 ---
    Breed('골든 리트리버', DogSize.large, EnergyLevel.high),
    Breed('래브라도 리트리버', DogSize.large, EnergyLevel.high),
    Breed('저먼 셰퍼드', DogSize.large, EnergyLevel.high),
    Breed('시베리안 허스키', DogSize.large, EnergyLevel.high),
    Breed('사모예드', DogSize.large, EnergyLevel.high),
    Breed('알래스칸 말라뮤트', DogSize.large, EnergyLevel.high),
    Breed('달마시안', DogSize.large, EnergyLevel.high),
    Breed('도베르만', DogSize.large, EnergyLevel.high),
    Breed('로트와일러', DogSize.large, EnergyLevel.medium),
    Breed('복서', DogSize.large, EnergyLevel.high, brachycephalic: true),
    Breed('그레이트 피레니즈', DogSize.large, EnergyLevel.low),
    Breed('세인트 버나드', DogSize.large, EnergyLevel.low),
    Breed('푸들(스탠다드)', DogSize.large, EnergyLevel.high),
    Breed('아키타', DogSize.large, EnergyLevel.medium),
    Breed('시고르자브종(믹스·대형)', DogSize.large, EnergyLevel.medium),
  ];

  static Breed? find(String? name) {
    if (name == null) return null;
    for (final b in all) {
      if (b.name == name) return b;
    }
    return null;
  }

  static List<String> get names => [for (final b in all) b.name];

  /// 검색어로 견종을 좁힌다. 공백은 무시한다 — "웰시코기"로도 찾히게.
  static List<Breed> search(String query) {
    final q = query.replaceAll(' ', '').toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final b in all)
        if (b.name.replaceAll(' ', '').toLowerCase().contains(q)) b,
    ];
  }
}
