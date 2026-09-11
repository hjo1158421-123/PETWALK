import 'dog.dart';

/// 반려견 프로필에서 뽑아낸 하루 권장 산책량.
///
/// 지금은 이력 화면의 달성률에 쓰지만, 산책로 추천이 붙으면 "이 아이에게
/// 맞는 코스 길이"를 정하는 입력이 된다.
///
/// 어디까지나 일반적인 기준을 계산한 값이다. 관절 질환이나 심장 질환이
/// 있는 아이는 기준이 완전히 달라지므로 수의사 상담이 먼저다.
class WalkGoal {
  const WalkGoal({
    required this.dailyDistanceM,
    required this.dailyMinutes,
    this.cautions = const [],
  });

  final double dailyDistanceM;
  final int dailyMinutes;

  /// 이 아이에게 특별히 주의할 점. 화면에 같이 보여 준다.
  final List<String> cautions;

  static const WalkGoal unknown =
      WalkGoal(dailyDistanceM: 2000, dailyMinutes: 40);

  factory WalkGoal.forDog(Dog dog) {
    final cautions = <String>[];

    // 몸집이 기준선을 정한다.
    var (distanceM, minutes) = switch (dog.size) {
      DogSize.small => (1500.0, 30),
      DogSize.medium => (3500.0, 60),
      DogSize.large => (5000.0, 75),
    };

    // 자견은 성장판이 닫히기 전이라 무리하면 관절에 부담이 간다.
    // 흔히 쓰이는 기준이 "월령 x 5분, 하루 두 번"이다.
    final months = dog.ageMonths;
    if (dog.isPuppy && months != null) {
      minutes = (months * 5 * 2).clamp(10, minutes);
      distanceM = minutes * 50.0; // 자견은 천천히 걷는다
      cautions.add('아직 자견이라 짧게 여러 번이 좋아요. 성장판이 닫히기 전에는 '
          '긴 산책이나 계단·점프가 관절에 부담을 줍니다.');
    } else {
      if (dog.isSenior) {
        distanceM *= 0.6;
        minutes = (minutes * 0.6).round();
        cautions.add('노령기에 접어들었어요. 한 번에 오래보다 짧게 나눠서, '
            '경사가 완만한 길이 좋습니다.');
      }

      final factor = switch (dog.energy) {
        EnergyLevel.low => 0.8,
        EnergyLevel.medium => 1.0,
        EnergyLevel.high => 1.3,
      };
      distanceM *= factor;
      minutes = (minutes * factor).round();
    }

    if (dog.brachycephalic) {
      // 단두종은 기도가 짧아 체온을 내리기 어렵다. 더위에 특히 위험하다.
      distanceM *= 0.6;
      minutes = (minutes * 0.6).round();
      cautions.add('코가 짧은 견종이라 숨이 쉽게 찹니다. 더운 날 낮 시간대는 '
          '피하고, 헥헥거리면 바로 쉬어 주세요.');
    }

    return WalkGoal(
      dailyDistanceM: distanceM,
      dailyMinutes: minutes,
      cautions: cautions,
    );
  }

  /// 여러 마리를 함께 산책시킬 때는 가장 약한 아이에게 맞춘다.
  factory WalkGoal.forDogs(List<Dog> dogs) {
    if (dogs.isEmpty) return unknown;
    final goals = dogs.map(WalkGoal.forDog).toList();
    goals.sort((a, b) => a.dailyDistanceM.compareTo(b.dailyDistanceM));
    final weakest = goals.first;
    return WalkGoal(
      dailyDistanceM: weakest.dailyDistanceM,
      dailyMinutes: weakest.dailyMinutes,
      cautions: [for (final g in goals) ...g.cautions],
    );
  }

  /// 오늘 걸은 거리 대비 달성률 (0.0 ~ 1.0 이상)
  double progressFor(double walkedM) =>
      dailyDistanceM <= 0 ? 0 : walkedM / dailyDistanceM;
}
