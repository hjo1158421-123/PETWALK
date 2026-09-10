import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/services/course_matcher.dart';
import 'package:petwalk/services/geo.dart';

void main() {
  group('geohash', () {
    test('알려진 좌표를 정확히 인코딩한다', () {
      // 위키백과 표준 예제: (57.64911, 10.40744) -> u4pruydqqvj8
      expect(geohashEncode(57.64911, 10.40744, precision: 12),
          equals('u4pruydqqvj8'));
    });

    test('정밀도가 낮은 해시는 높은 해시의 접두사다', () {
      // 이 계층 구조 덕분에 셀 크기를 바꿔도 인덱스를 다시 만들 필요가 없다.
      final fine = geohashEncode(37.5665, 126.9780, precision: 9);
      final coarse = geohashEncode(37.5665, 126.9780, precision: 5);
      expect(fine.startsWith(coarse), isTrue);
    });

    test('멀리 떨어진 지점은 다른 셀이 된다', () {
      final seoul = geohashEncode(37.5665, 126.9780);
      final busan = geohashEncode(35.1796, 129.0756);
      expect(seoul, isNot(equals(busan)));
    });
  });

  group('CourseMatcher', () {
    test('거의 겹치는 경로는 같은 코스로 본다', () {
      final a = {'wydm6q1', 'wydm6q2', 'wydm6q3', 'wydm6q4', 'wydm6q5'};
      // 한 셀만 다르게 밟은 같은 길
      final b = {'wydm6q1', 'wydm6q2', 'wydm6q3', 'wydm6q4', 'wydm6q9'};

      expect(CourseMatcher.jaccard(a, b),
          greaterThanOrEqualTo(CourseMatcher.threshold));
    });

    test('절반만 겹치는 경로는 다른 코스로 본다', () {
      final a = {'wydm6q1', 'wydm6q2', 'wydm6q3', 'wydm6q4'};
      final b = {'wydm6q3', 'wydm6q4', 'wydm6r1', 'wydm6r2'};

      expect(CourseMatcher.jaccard(a, b), lessThan(CourseMatcher.threshold));
    });

    test('겹치는 셀이 없으면 0이다', () {
      expect(CourseMatcher.jaccard({'a'}, {'b'}), equals(0));
      expect(CourseMatcher.jaccard({}, {'b'}), equals(0));
    });

    test('같은 셀을 지나도 거리가 크게 다르면 다른 코스다', () {
      // 한 바퀴 vs 두 바퀴는 셀 집합이 같아도 같은 코스가 아니다.
      expect(CourseMatcher.distanceCompatible(2000, 4000), isFalse);
      expect(CourseMatcher.distanceCompatible(2000, 2200), isTrue);
    });
  });
}
