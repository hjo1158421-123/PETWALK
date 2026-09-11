import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petwalk/services/theme_controller.dart';
import 'package:petwalk/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 글꼴을 뺀 토큰 한 벌.
///
/// `buildTheme()` 을 그대로 부르지 않는 이유는 그것이 google_fonts 를 건드려
/// 망을 타기 때문이다. 테스트에서는 실패하고, 그 예외가 비동기로 새어 나와
/// 엉뚱한 테스트를 깨뜨린다. 여기서 확인하려는 건 글꼴 파일이 아니라
/// 색·모양 토큰과 lerp 안전성이다.
PetWalkTokens _tokens(AppThemeVariant variant) => PetWalkTokens(
      variant: variant,
      accent: variant == AppThemeVariant.cozy
          ? const Color(0xFFF59A4B)
          : const Color(0xFF1F5B3A),
      accentSoft: const Color(0xFFEEEEEE),
      accentText: const Color(0xFF333333),
      muted: const Color(0xFF888888),
      faint: const Color(0xFFBBBBBB),
      hairline: const Color(0xFFE0E0E0),
      cardRadius: variant == AppThemeVariant.cozy ? 26 : 16,
      chipRadius: variant == AppThemeVariant.cozy ? 999 : 6,
      buttonRadius: variant == AppThemeVariant.cozy ? 999 : 16,
      cardElevation: 0,
      usesHairline: variant == AppThemeVariant.minimal,
      chartBars: const [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
      chartPeak: const Color(0xFF444444),
      display: const TextStyle(fontFamily: 'DisplayStub'),
      caption: const TextStyle(fontFamily: 'CaptionStub'),
    );

void main() {
  group('테마 전환', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('두 안을 번갈아 오간다', () async {
      final c = ThemeController();
      expect(c.variant, AppThemeVariant.cozy);

      await c.toggle();
      expect(c.variant, AppThemeVariant.minimal);

      await c.toggle();
      expect(c.variant, AppThemeVariant.cozy);
    });

    test('바뀌면 화면에 알린다', () async {
      final c = ThemeController();
      var notified = 0;
      c.addListener(() => notified++);

      await c.toggle();
      expect(notified, 1);

      // 같은 값을 다시 고르면 다시 그릴 이유가 없다.
      await c.select(c.variant);
      expect(notified, 1);
    });

    test('고른 테마는 앱을 껐다 켜도 남는다', () async {
      await ThemeController().select(AppThemeVariant.minimal);

      final restarted = ThemeController();
      await restarted.load();
      expect(restarted.variant, AppThemeVariant.minimal);
    });

    test('저장된 값이 없으면 기본 테마로 시작한다', () async {
      final c = ThemeController();
      await c.load();
      expect(c.variant, AppThemeVariant.cozy);
    });

    test('저장된 값이 깨져 있어도 앱은 뜬다', () async {
      // 예전 버전이 남긴 값이나 손상된 설정을 만나도 죽으면 안 된다.
      SharedPreferences.setMockInitialValues({'theme_variant': '알 수 없는 값'});

      final c = ThemeController();
      await c.load();
      expect(c.variant, AppThemeVariant.cozy);
    });

    test('두 안은 서로를 next 로 가리킨다', () {
      expect(AppThemeVariant.cozy.next, AppThemeVariant.minimal);
      expect(AppThemeVariant.minimal.next, AppThemeVariant.cozy);
    });
  });

  group('테마 토큰', () {
    test('두 안의 형태가 실제로 다르다', () {
      final cozy = _tokens(AppThemeVariant.cozy);
      final minimal = _tokens(AppThemeVariant.minimal);

      // 1a 는 둥근 pill, 1b 는 각진 면. 여기가 같아지면 두 안을 나눈 의미가 없다.
      expect(cozy.buttonRadius, greaterThan(minimal.buttonRadius));
      expect(cozy.usesHairline, isFalse);
      expect(minimal.usesHairline, isTrue);
    });

    test('색을 섞는 중간에도 토큰이 온전하다', () {
      // 테마를 바꾸면 Flutter 가 lerp 로 두 테마를 섞는다. 이 과정에서
      // 값이 새거나 배열 길이가 어긋나면 전환하는 순간에만 죽는 버그가 된다.
      final cozy = _tokens(AppThemeVariant.cozy);
      final minimal = _tokens(AppThemeVariant.minimal);

      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final mid = cozy.lerp(minimal, t);
        expect(mid.chartBars, hasLength(3));
        expect(mid.display.fontFamily, isNotNull);
        expect(mid.caption.fontFamily, isNotNull);
      }
    });

    test('섞는 도중 글꼴과 모양은 한쪽 값을 통째로 쓴다', () {
      // 글꼴 이름이나 "선을 쓰는가" 같은 값은 중간값이 의미가 없다.
      // 절반을 넘는 순간 통째로 넘어가야 한다.
      final cozy = _tokens(AppThemeVariant.cozy);
      final minimal = _tokens(AppThemeVariant.minimal);

      expect(cozy.lerp(minimal, 0.2).usesHairline, isFalse);
      expect(cozy.lerp(minimal, 0.8).usesHairline, isTrue);
    });

    test('상대가 없으면 자기 자신을 유지한다', () {
      final cozy = _tokens(AppThemeVariant.cozy);
      expect(cozy.lerp(null, 0.5), same(cozy));
    });
  });
}
