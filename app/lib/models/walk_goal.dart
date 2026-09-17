import '../data/breed_catalog.dart';
import 'dog.dart';

/// 권장량 하나하나의 근거.
///
/// 화면에 "왜 이런 말을 하는지"를 같이 보여 주기 위해 문구와 출처를 묶어
/// 들고 다닌다. 근거 없이 단정하는 문장을 띄우지 않기 위한 장치다.
class Caution {
  const Caution(this.text, {required this.source});

  final String text;

  /// 논문이나 가이드라인. 출처가 없는 경험칙이면 그렇다고 적는다.
  final String source;
}

/// 반려견 프로필에서 뽑아낸 하루 권장 산책량.
///
/// **시간이 주 목표이고 거리는 참고치다.** 수의학 가이드라인이 실제로
/// 말하는 단위가 시간이기 때문이다(AKC 기준 하루 30분~2시간). 거리를 주
/// 목표로 두면 어떤 문헌에서도 출처를 가져올 수 없다. 예전에는 거리를
/// 기준으로 삼았지만 근거를 붙일 수 없어서 뒤집었다.
///
/// 각 값 옆에 근거를 적어 두었고, **근거를 찾지 못한 값은 "근거 없음"이라고
/// 분명히 적었다.** 나중에 수치를 검증할 때 어디부터 봐야 하는지 알아야
/// 하기 때문이다. 전체 출처 목록은 docs/권장산책량-근거.md 에 있다.
///
/// 어디까지나 건강한 개를 전제한 일반 기준이다. 관절 질환이나 심장 질환이
/// 있는 아이는 기준이 완전히 달라지므로 수의사 상담이 먼저다.
class WalkGoal {
  const WalkGoal({
    required this.dailyMinutes,
    required this.sessionMinutes,
    required this.sessionsPerDay,
    this.cautions = const [],
    this.hasBreedEvidence = false,
  });

  /// 하루 총 산책 시간. 이게 진짜 목표다.
  final int dailyMinutes;

  /// 한 번에 걷는 시간. 총량이 같아도 나눠 걷는 게 나은 경우가 있다.
  final int sessionMinutes;

  final int sessionsPerDay;

  final List<Caution> cautions;

  /// 기준선(dailyMinutes 의 출발점)이 견종별 실측 자료에서 왔는지.
  ///
  /// true 면 `BreedCatalog` 에 있는 켄넬클럽 권장치를 그대로 썼다는
  /// 뜻이고, false 면 몸집만 보고 추정한 값(근거 없음)이라는 뜻이다.
  /// 화면에서 "이 숫자가 얼마나 믿을 만한가"를 다르게 보여 주는 데 쓴다.
  final bool hasBreedEvidence;

  /// 보통 걸음 속도(m/분) 가정치.
  ///
  /// **근거 없음.** 개는 냄새를 맡느라 자주 멈춰서 사람 보행 속도보다 느리다.
  /// 시속 3.3km 정도로 잡았다. 거리를 "환산 참고치"로만 쓰는 이유가 이것이다.
  /// 실기기 기록이 쌓이면 실제 평균 속도로 바꿀 것.
  static const double walkPaceMPerMin = 55;

  /// 시간에서 환산한 참고 거리. 목표가 아니다.
  double get dailyDistanceM => dailyMinutes * walkPaceMPerMin;

  static const WalkGoal unknown =
      WalkGoal(dailyMinutes: 45, sessionMinutes: 23, sessionsPerDay: 2);

  factory WalkGoal.forDog(Dog dog) {
    final cautions = <Caution>[];

    // 견종이 카탈로그에 있고 켄넬클럽 권장치를 알고 있으면 그 값을
    // 기준선으로 쓴다. 없으면 몸집만 보고 추정한다.
    final breedMinutes = BreedCatalog.find(dog.breed)?.recommendedMinutes;
    final hasBreedEvidence = breedMinutes != null;

    var minutes = breedMinutes ??
        // 몸집이 기준선을 정한다.
        //
        // AKC 는 "하루 30분~2시간"이라는 범위만 제시하고, 켄넬클럽의
        // 세분화된 기준은 몸집이 아니라 견종별이다. 그래서 범위 안에서
        // 몸집에 따라 나눈 이 숫자들 자체는 **근거 없음**이다. 방향
        // (클수록 길게)만 상식에 맞춰 두었다. 견종을 알면 이 분기를 타지
        // 않는다 — `BreedCatalog.recommendedMinutes` 가 채워진 견종 목록은
        // docs/권장산책량-근거.md 참조.
        switch (dog.size) {
          DogSize.small => 45,
          DogSize.medium => 60,
          DogSize.large => 75,
        };
    var sessions = 2;

    final months = dog.ageMonths;
    if (dog.isPuppy && months != null) {
      // 흔히 쓰는 "월령 x 5분" 규칙은 쓰지 않는다.
      //
      // 한 번도 직접 검증된 적 없는 경험칙이고, 활동적인 워킹 견종에겐
      // 부족한 반면 토이 견종이나 단두종에겐 과할 수 있다. 최근에는 권하지
      // 않는 수의사가 늘었다.
      //
      // 실제 연구(Krontveit 2012)가 말하는 것은 "얼마나"가 아니라
      // "어떻게"다. 생후 3개월 이전 계단 이용은 고관절 이형성증 위험을
      // 높였고, 목줄 없이 자유롭게 뛰거나 완만하게 굴곡진 부드러운 지면에서
      // 논 강아지는 오히려 위험이 낮았다. 그래서 시간은 보수적으로만 잡고
      // 진짜 조언은 cautions 로 전달한다.
      //
      // 성견 기준선(견종 실측이든 몸집 추정이든)까지 월령 비례로 올리는
      // 이 보간 자체는 **근거 없음**이다.
      minutes = (minutes * months / 12).round().clamp(15, minutes);
      sessions = 3;

      cautions.add(const Caution(
        '아직 자견이라 한 번에 오래보다 짧게 여러 번이 좋아요. '
        '목줄을 풀고 스스로 속도를 정하게 두는 편이 관절에 이롭습니다.',
        source: 'Krontveit et al. 2012, Am J Vet Res 73(6):838-846 — '
            '자유 운동은 고관절 이형성증 위험을 낮췄다',
      ));

      if (months < 3) {
        cautions.add(const Caution(
          '생후 3개월 전에는 계단을 오르내리지 않게 해 주세요. '
          '흙길처럼 부드럽고 완만하게 굴곡진 길이 가장 좋습니다.',
          source: 'Krontveit et al. 2012, Am J Vet Res 73(6):838-846 — '
              '3개월 이전 계단 이용은 고관절 이형성증 위험을 높였다',
        ));
      }
    } else {
      if (dog.isSenior) {
        // 총량을 깎지 않는다. 예전에는 0.6배로 줄였지만 방향이 거꾸로였다.
        //
        // COAST 국제 합의 가이드라인과 AAHA 2022 통증 관리 지침에서 통제된
        // 규칙적 운동은 관절염의 1차(tier 1) 치료다. 줄일 대상이 아니라
        // 유지할 대상이다. 쉬는 동안 관절이 굳기 때문에 총량을 줄이는 것보다
        // 간격을 좁혀 자주 걷는 편이 낫다.
        sessions = 3;

        cautions.add(const Caution(
          '나이가 있는 아이는 한 번에 오래보다 짧게 자주가 좋습니다. '
          '쉬는 동안 관절이 굳기 때문에, 총량을 줄이기보다 나눠서 걸어 주세요. '
          '힘들어하면 그날그날 줄이시고요.',
          source: 'COAST 국제 합의 가이드라인 / AAHA 2022 통증 관리 지침 — '
              '통제된 규칙적 운동은 관절염의 1차 치료',
        ));

        cautions.add(const Caution(
          '나이 든 아이는 더위 자체에 약합니다. 한여름 한낮은 피해 주세요.',
          source: 'Hall et al. 2020, Animals 10:1324 — '
              '12세 이상은 환경성 열사병 오즈비 3.15배',
        ));
      }

      // 활동량 배수. **근거 없음.**
      //
      // 견종 기준선(hasBreedEvidence)을 썼을 때는 곱하지 않는다. 켄넬클럽
      // 권장치는 이미 그 견종의 평균적인 활동 성향을 반영한 값이라, 여기에
      // 근거 없는 배수를 또 곱하면 근거 있는 숫자를 근거 없는 숫자로 다시
      // 덮어쓰는 꼴이 된다. 몸집만으로 추정했을 때만 활동량으로 보정한다.
      if (!hasBreedEvidence) {
        final factor = switch (dog.energy) {
          EnergyLevel.low => 0.8,
          EnergyLevel.medium => 1.0,
          EnergyLevel.high => 1.3,
        };
        minutes = (minutes * factor).round();
      }
    }

    if (dog.brachycephalic) {
      // 단두종은 기도가 짧아 헐떡임으로 체온을 내리기 어렵다.
      //
      // 문헌(Hall 2020)이 실제로 말하는 것은 "운동 중 열사병 위험이
      // 높다"는 것이지 "운동량 자체를 줄여야 한다"가 아니다 — 오즈비는
      // 강도·환경 대비 위험을 말할 뿐 적정 시간을 말하지 않는다. 그래서
      // 견종 기준선(hasBreedEvidence)이 있으면 시간을 줄이지 않는다.
      // 프렌치 불독·퍼그처럼 켄넬클럽 표에 이미 있는 단두종은 그 권장치
      // 자체가 해당 견종의 정상 활동량이므로, 거기에 또 배수를 곱하면
      // 근거 있는 값을 근거 없는 값으로 덮어쓰게 된다.
      //
      // 몸집만으로 추정했을 때는 예전처럼 ×0.7 을 쓴다. 줄여야 한다는
      // **방향은 근거가 분명하지만, 0.7 이라는 배수 자체는 근거 없음**이다.
      if (!hasBreedEvidence) {
        minutes = (minutes * 0.7).round();
      }

      cautions.add(const Caution(
        '코가 짧은 견종이라 숨이 쉽게 찹니다. 헥헥거리면 바로 쉬어 주세요. '
        '더운 날 낮 시간대는 피하는 게 좋습니다.',
        source: 'Hall et al. 2020, Sci Rep 10:9128 — '
            '단두종은 열 관련 질환 오즈비 2.10배 (95% CI 1.68-2.64)',
      ));
    }

    // 체중이 많이 나가는 개일수록 열에 취약하다. 대형견에게 가장 긴 산책을
    // 주면서 이 점을 빠뜨리면 앱이 위험한 방향으로 등을 떠미는 셈이 된다.
    if ((dog.weightKg ?? 0) > 50) {
      cautions.add(const Caution(
        '덩치가 큰 아이는 열이 잘 빠지지 않습니다. 더운 날에는 시간을 줄이고 '
        '그늘과 물을 자주 챙겨 주세요.',
        source: 'Hall et al. 2020, Sci Rep 10:9128 — '
            '50kg 초과는 열 관련 질환 오즈비 3.42배 (10kg 미만 대비)',
      ));
    }

    // 배수를 곱으로 쌓다 보면 바닥까지 떨어질 수 있어 하한을 둔다.
    // 자견은 원래 짧게 걷는 게 맞으므로 더 낮게 잡는다.
    minutes = minutes.clamp(dog.isPuppy ? 10 : 20, 180);

    return WalkGoal(
      dailyMinutes: minutes,
      sessionMinutes: (minutes / sessions).round().clamp(5, minutes),
      sessionsPerDay: sessions,
      cautions: cautions,
      hasBreedEvidence: hasBreedEvidence,
    );
  }

  /// 여러 마리를 함께 산책시킬 때는 가장 약한 아이에게 맞춘다.
  /// 대형견에 맞추면 함께 나간 노령 소형견이 무리하게 된다.
  factory WalkGoal.forDogs(List<Dog> dogs) {
    if (dogs.isEmpty) return unknown;
    final goals = dogs.map(WalkGoal.forDog).toList();
    goals.sort((a, b) => a.dailyMinutes.compareTo(b.dailyMinutes));
    final weakest = goals.first;
    return WalkGoal(
      dailyMinutes: weakest.dailyMinutes,
      sessionMinutes: weakest.sessionMinutes,
      sessionsPerDay: weakest.sessionsPerDay,
      cautions: [for (final g in goals) ...g.cautions],
      // 여러 마리 중 가장 약한 아이 기준을 썼으니, 신뢰도 표시도 그
      // 아이의 것을 따라간다.
      hasBreedEvidence: weakest.hasBreedEvidence,
    );
  }

  /// 오늘 걸은 시간 대비 달성률 (0.0 ~ 1.0 이상)
  double progressFor(Duration walked) => dailyMinutes <= 0
      ? 0
      : walked.inSeconds / (dailyMinutes * 60);
}
