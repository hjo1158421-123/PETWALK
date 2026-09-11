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
}) {
  int? birthYm;
  if (ageMonths != null) {
    final now = DateTime.now();
    final total = now.year * 12 + now.month - ageMonths;
    birthYm = (total ~/ 12) * 100 + (total % 12 == 0 ? 12 : total % 12);
  }
  return Dog(
    name: '테스트',
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
}
