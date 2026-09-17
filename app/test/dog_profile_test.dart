import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/data/breed_catalog.dart';
import 'package:petwalk/models/dog.dart';
import 'package:petwalk/models/walk_goal.dart';

Dog _dog({
  DogSize size = DogSize.medium,
  EnergyLevel energy = EnergyLevel.medium,
  bool brachycephalic = false,
  int? ageMonths,
  double? weightKg,
  String? breed,
}) {
  int? birthYm;
  if (ageMonths != null) {
    final now = DateTime.now();
    final total = now.year * 12 + now.month - ageMonths;
    birthYm = (total ~/ 12) * 100 + (total % 12 == 0 ? 12 : total % 12);
  }
  return Dog(
    name: '테스트',
    breed: breed,
    size: size,
    energy: energy,
    brachycephalic: brachycephalic,
    birthYm: birthYm,
    weightKg: weightKg,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('견종 카탈로그', () {
    test('단두종이 실제로 표시돼 있다', () {
      // 추천 단계에서 여름 시간대를 막는 판단의 근거가 되는 값이다.
      for (final name in ['퍼그', '프렌치 불독', '시츄', '페키니즈']) {
        expect(BreedCatalog.find(name)?.brachycephalic, isTrue,
            reason: '$name 은 단두종이어야 한다');
      }
      expect(BreedCatalog.find('보더 콜리')?.brachycephalic, isFalse);
    });

    test('공백을 무시하고 검색된다', () {
      expect(BreedCatalog.search('웰시코기').map((b) => b.name),
          contains('웰시 코기'));
    });

    test('켄넬클럽 권장치는 30/60/120 세 구간 중 하나다', () {
      // Carter & Farnworth (2021) 논문 표에 실제로 있는 구간이 이
      // 세 개뿐이다. 다른 값이 들어오면 출처 없이 지어낸 숫자라는 뜻이다.
      for (final b in BreedCatalog.all) {
        final m = b.recommendedMinutes;
        if (m == null) continue;
        expect([30, 60, 120], contains(m),
            reason: '${b.name} 의 $m 분은 논문 표에 없는 구간이다');
      }
    });

    test('견종별 권장치가 있으면 몸집 구간과 방향이 어긋나지 않는다', () {
      // 소형견이 대형견보다 권장 시간이 긴 경우가 있으면 안 된다 —
      // 최소한 "몸집이 클수록 길다"는 상식과는 맞아야 한다는 방어선이다.
      final withEvidence = [
        for (final b in BreedCatalog.all)
          if (b.recommendedMinutes != null) b
      ];
      expect(withEvidence, isNotEmpty);

      for (final b in withEvidence) {
        if (b.size == DogSize.small) {
          expect(b.recommendedMinutes, lessThanOrEqualTo(60),
              reason: '${b.name}(소형견)의 권장치가 비정상적으로 길다');
        }
        if (b.size == DogSize.large) {
          expect(b.recommendedMinutes, greaterThanOrEqualTo(60),
              reason: '${b.name}(대형견)의 권장치가 비정상적으로 짧다');
        }
      }
    });

    test('견종을 고르면 크기와 단두종 여부가 채워진다', () {
      final dog = Dog.fromBreed('콩이', '퍼그');
      expect(dog.size, DogSize.small);
      expect(dog.brachycephalic, isTrue);
      expect(dog.energy, EnergyLevel.low);
    });
  });

  group('나이 계산', () {
    test('12개월 미만은 자견이다', () {
      expect(_dog(ageMonths: 6).isPuppy, isTrue);
      expect(_dog(ageMonths: 18).isPuppy, isFalse);
    });

    test('노령 기준은 몸집이 클수록 빨리 온다', () {
      // 7살: 대형견은 노령, 소형견은 아직 아니다
      expect(_dog(size: DogSize.large, ageMonths: 7 * 12).isSenior, isTrue);
      expect(_dog(size: DogSize.small, ageMonths: 7 * 12).isSenior, isFalse);
    });

    test('생년월을 모르면 노령 판정을 하지 않는다', () {
      expect(_dog().isSenior, isFalse);
      expect(_dog().ageText, '나이 모름');
    });
  });

  group('권장 산책량', () {
    test('몸집이 클수록 많이 걷는다', () {
      final small = WalkGoal.forDog(_dog(size: DogSize.small)).dailyMinutes;
      final large = WalkGoal.forDog(_dog(size: DogSize.large)).dailyMinutes;
      expect(large, greaterThan(small));
    });

    test('성견 권장 시간은 AKC 범위(30~120분) 안에 든다', () {
      for (final size in DogSize.values) {
        for (final energy in EnergyLevel.values) {
          final goal =
              WalkGoal.forDog(_dog(size: size, energy: energy, ageMonths: 36));
          expect(goal.dailyMinutes, inInclusiveRange(30, 120),
              reason: '$size / $energy 가 범위를 벗어났다');
        }
      }
    });

    test('노령견은 총량을 깎지 않고 짧게 여러 번으로 나눈다', () {
      // 예전에는 0.6배로 줄였다. COAST/AAHA 기준으로 통제된 규칙적 운동은
      // 관절염의 1차 치료라 줄일 대상이 아니다. 방향을 뒤집은 것이라
      // 회귀하지 않도록 테스트로 못을 박는다.
      final adult = WalkGoal.forDog(_dog(ageMonths: 3 * 12));
      final senior = WalkGoal.forDog(_dog(ageMonths: 10 * 12));

      expect(senior.dailyMinutes, adult.dailyMinutes);
      expect(senior.sessionsPerDay, greaterThan(adult.sessionsPerDay));
      expect(senior.sessionMinutes, lessThan(adult.sessionMinutes));
      expect(senior.cautions, isNotEmpty);
    });

    test('단두종은 권장량을 줄이고 더위 주의를 알린다', () {
      final normal = WalkGoal.forDog(_dog(ageMonths: 36));
      final brachy = WalkGoal.forDog(_dog(ageMonths: 36, brachycephalic: true));
      expect(brachy.dailyMinutes, lessThan(normal.dailyMinutes));
      expect(brachy.cautions.map((c) => c.text).join(), contains('더운 날'));
    });

    test('자견은 짧게 잡고, 계단 대신 부드러운 지면을 권한다', () {
      // "월령 x 5분" 규칙은 근거가 없어 버렸다. 대신 Krontveit 2012 가
      // 말하는 "무엇을 하느냐"를 전달하는지 확인한다.
      final puppy = WalkGoal.forDog(_dog(ageMonths: 2));
      final adult = WalkGoal.forDog(_dog(ageMonths: 36));

      expect(puppy.dailyMinutes, lessThan(adult.dailyMinutes));
      expect(puppy.cautions.map((c) => c.text).join(), contains('계단'));
    });

    test('모든 주의 문구는 출처를 달고 나온다', () {
      // 근거 없이 단정하는 문장을 화면에 띄우지 않기 위한 방어선이다.
      final dog = _dog(
          ageMonths: 2, size: DogSize.large, brachycephalic: true, weightKg: 60);
      final goal = WalkGoal.forDog(dog);

      expect(goal.cautions, isNotEmpty);
      for (final c in goal.cautions) {
        expect(c.source.trim(), isNotEmpty, reason: '"${c.text}" 에 출처가 없다');
      }
    });

    test('여러 마리면 가장 약한 아이에게 맞춘다', () {
      final big = _dog(size: DogSize.large, energy: EnergyLevel.high);
      final senior = _dog(size: DogSize.small, ageMonths: 12 * 12);

      final goal = WalkGoal.forDogs([big, senior]);
      expect(goal.dailyMinutes, WalkGoal.forDog(senior).dailyMinutes);
      // 주의 문구는 모든 아이 것을 모아 보여 준다
      expect(goal.cautions, isNotEmpty);
    });
  });

  group('견종별 실측 근거 (Carter & Farnworth 2021, UK 켄넬클럽 권장치)', () {
    test('카탈로그에 있는 견종은 그 값을 그대로 쓰고 근거 있음으로 표시한다', () {
      final goal =
          WalkGoal.forDog(_dog(breed: '골든 리트리버', size: DogSize.large, ageMonths: 36));

      expect(goal.hasBreedEvidence, isTrue);
      expect(goal.dailyMinutes, 120);
    });

    test('카탈로그에 없는 견종(직접 입력)은 몸집 추정을 쓰고 근거 없음으로 표시한다', () {
      final withUnknownBreed =
          WalkGoal.forDog(_dog(breed: '알 수 없는 잡종', size: DogSize.medium, ageMonths: 36));
      final withoutBreed =
          WalkGoal.forDog(_dog(breed: null, size: DogSize.medium, ageMonths: 36));

      expect(withUnknownBreed.hasBreedEvidence, isFalse);
      expect(withoutBreed.hasBreedEvidence, isFalse);
    });

    test('견종 기준값이 있으면 활동량을 다르게 입력해도 흔들리지 않는다', () {
      // 활동량 배수(0.8~1.3)는 근거가 없다. 켄넬클럽 권장치는 이미 그
      // 견종의 평균 활동 성향을 반영하므로, 여기에 근거 없는 배수를
      // 또 곱하면 근거 있는 값을 근거 없는 값으로 덮어쓰는 셈이 된다.
      final low = WalkGoal.forDog(
          _dog(breed: '비글', energy: EnergyLevel.low, ageMonths: 36));
      final high = WalkGoal.forDog(
          _dog(breed: '비글', energy: EnergyLevel.high, ageMonths: 36));

      expect(low.dailyMinutes, 60);
      expect(high.dailyMinutes, 60);
    });

    test('견종 기준값이 있는 단두종은 시간을 줄이지 않지만 주의 문구는 그대로 붙는다', () {
      // 프렌치 불독은 카탈로그에 60분으로 실려 있다. 이 60분 자체가 이미
      // "프렌치 불독의 정상 활동량"이므로 예전처럼 x0.7 을 또 곱이지 않는다.
      // brachycephalic 은 Dog.fromBreed() 를 거쳐야 카탈로그에서 자동으로
      // 채워지므로, Dog() 생성자만 쓰는 이 테스트에서는 직접 명시한다.
      final catalogGoal = WalkGoal.forDog(
          _dog(breed: '프렌치 불독', ageMonths: 36, brachycephalic: true));
      expect(catalogGoal.hasBreedEvidence, isTrue);
      expect(catalogGoal.dailyMinutes, 60,
          reason: '켄넬클럽 권장치 자체를 또 깎으면 안 된다');
      expect(catalogGoal.cautions.map((c) => c.text).join(), contains('더운 날'));

      // 같은 단두종이라도 카탈로그에 없으면(직접 입력) 여전히 몸집
      // 추정 + x0.7 감축이 적용된다 — 이 경로는 그대로 유지돼야 한다.
      final normal = WalkGoal.forDog(_dog(ageMonths: 36));
      final unlistedBrachy =
          WalkGoal.forDog(_dog(ageMonths: 36, brachycephalic: true));
      expect(unlistedBrachy.hasBreedEvidence, isFalse);
      expect(unlistedBrachy.dailyMinutes, lessThan(normal.dailyMinutes));
    });

    test('견종 기준값이 있는 자견은 그 견종의 성견 기준에서 월령 비례로 계산된다', () {
      // 골든 리트리버(120분) 6개월이면 120 * 6/12 = 60분이어야 한다.
      final goal = WalkGoal.forDog(_dog(breed: '골든 리트리버', ageMonths: 6));
      expect(goal.hasBreedEvidence, isTrue);
      expect(goal.dailyMinutes, 60);
    });

    test('여러 마리 조합에서도 신뢰도 표시가 가장 약한 아이를 따라간다', () {
      final catalogDog = _dog(breed: '골든 리트리버', size: DogSize.large);
      final unlistedSenior = _dog(size: DogSize.small, ageMonths: 12 * 12);

      final goal = WalkGoal.forDogs([catalogDog, unlistedSenior]);
      // 더 약한(시간이 짧은) 쪽은 카탈로그에 없는 소형 노령견이다.
      expect(goal.hasBreedEvidence, isFalse);
    });
  });
}
