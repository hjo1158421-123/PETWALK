import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/data/breed_catalog.dart';
import 'package:petwalk/models/dog.dart';
import 'package:petwalk/models/walk_goal.dart';

Dog _dog({
  DogSize size = DogSize.medium,
  EnergyLevel energy = EnergyLevel.medium,
  bool brachycephalic = false,
  int? ageMonths,
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
      final small = WalkGoal.forDog(_dog(size: DogSize.small)).dailyDistanceM;
      final large = WalkGoal.forDog(_dog(size: DogSize.large)).dailyDistanceM;
      expect(large, greaterThan(small));
    });

    test('노령견은 권장량이 줄고 주의 문구가 붙는다', () {
      final adult = WalkGoal.forDog(_dog(ageMonths: 3 * 12));
      final senior = WalkGoal.forDog(_dog(ageMonths: 10 * 12));
      expect(senior.dailyDistanceM, lessThan(adult.dailyDistanceM));
      expect(senior.cautions, isNotEmpty);
    });

    test('단두종은 권장량을 줄이고 더위 주의를 알린다', () {
      final normal = WalkGoal.forDog(_dog(ageMonths: 36));
      final brachy = WalkGoal.forDog(_dog(ageMonths: 36, brachycephalic: true));
      expect(brachy.dailyDistanceM, lessThan(normal.dailyDistanceM));
      expect(brachy.cautions.join(), contains('더운 날'));
    });

    test('자견은 월령 기준으로 짧게 잡고 주의 문구를 붙인다', () {
      final puppy = WalkGoal.forDog(_dog(ageMonths: 4));
      final adult = WalkGoal.forDog(_dog(ageMonths: 36));
      expect(puppy.dailyMinutes, lessThan(adult.dailyMinutes));
      expect(puppy.cautions.join(), contains('성장판'));
    });

    test('여러 마리면 가장 약한 아이에게 맞춘다', () {
      final big = _dog(size: DogSize.large, energy: EnergyLevel.high);
      final senior = _dog(size: DogSize.small, ageMonths: 12 * 12);

      final goal = WalkGoal.forDogs([big, senior]);
      expect(goal.dailyDistanceM, WalkGoal.forDog(senior).dailyDistanceM);
      // 주의 문구는 모든 아이 것을 모아 보여 준다
      expect(goal.cautions, isNotEmpty);
    });
  });
}
