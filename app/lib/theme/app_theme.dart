import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 전체의 시각 테마. 디자인 핸드오프의 1a / 1b 두 안이다.
///
/// 정보 구조와 탭 구성은 두 안이 완전히 같다. 다른 것은 색·글꼴·모서리·
/// 구분선뿐이다. 그래서 화면을 두 벌 만들지 않고 **토큰만 갈아끼운다.**
/// 화면을 복제했다면 이후 모든 수정을 두 번씩 해야 했을 것이다.
enum AppThemeVariant {
  cozy('포근한 산책 수첩', '둥근 카드 · 크림 톤 · 손글씨'),
  minimal('미니멀 트래커', '종이 톤 · 굵은 헤드라인 · 얇은 선');

  const AppThemeVariant(this.label, this.description);

  final String label;
  final String description;

  AppThemeVariant get next =>
      this == AppThemeVariant.cozy ? AppThemeVariant.minimal : AppThemeVariant.cozy;
}

/// Material 의 ColorScheme 이 담지 못하는 디자인 토큰.
///
/// 두 안의 차이는 색만이 아니다. 1a 는 둥근 카드에 그림자를 쓰고 1b 는
/// 각진 면에 1px 선을 쓴다. 이 "형태" 차이를 위젯마다 if 로 갈라 쓰면
/// 금방 엉키므로 값으로 뽑아 두고 위젯은 값만 읽는다.
@immutable
class PetWalkTokens extends ThemeExtension<PetWalkTokens> {
  const PetWalkTokens({
    required this.variant,
    required this.accent,
    required this.accentSoft,
    required this.accentText,
    required this.muted,
    required this.faint,
    required this.hairline,
    required this.cardRadius,
    required this.chipRadius,
    required this.buttonRadius,
    required this.cardElevation,
    required this.usesHairline,
    required this.chartBars,
    required this.chartPeak,
    required this.display,
    required this.caption,
  });

  final AppThemeVariant variant;

  /// 주 포인트 색. 버튼과 진행률에 쓴다.
  final Color accent;

  /// 포인트의 연한 톤. 배지와 선택된 탭 배경.
  final Color accentSoft;

  /// 연한 배경 위에 얹는 포인트 텍스트 색. accent 를 그대로 쓰면 대비가 모자란다.
  final Color accentText;

  /// 보조 텍스트.
  final Color muted;

  /// 더 흐린 텍스트. 캡션과 비활성 라벨.
  final Color faint;

  /// 1px 구분선. 1b 의 뼈대다.
  final Color hairline;

  final double cardRadius;
  final double chipRadius;
  final double buttonRadius;

  /// 1a 는 그림자로 카드를 띄우고, 1b 는 그림자 없이 선으로 나눈다.
  final double cardElevation;

  /// 카드 테두리를 1px 선으로 그릴지. 1b 전용.
  final bool usesHairline;

  /// 주간 막대 차트의 색 계단. 낮은 값 → 높은 값 순.
  final List<Color> chartBars;

  /// 그 주 최대값 막대.
  final Color chartPeak;

  /// 수치를 크게 보여 줄 때 쓰는 글꼴. 두 안의 인상 차이가 여기서 갈린다.
  final TextStyle display;

  /// 1b 의 모노스페이스 대문자 캡션. 1a 에서는 평범한 소문자 캡션이다.
  final TextStyle caption;

  static PetWalkTokens of(BuildContext context) =>
      Theme.of(context).extension<PetWalkTokens>()!;

  @override
  PetWalkTokens copyWith({
    AppThemeVariant? variant,
    Color? accent,
    Color? accentSoft,
    Color? accentText,
    Color? muted,
    Color? faint,
    Color? hairline,
    double? cardRadius,
    double? chipRadius,
    double? buttonRadius,
    double? cardElevation,
    bool? usesHairline,
    List<Color>? chartBars,
    Color? chartPeak,
    TextStyle? display,
    TextStyle? caption,
  }) =>
      PetWalkTokens(
        variant: variant ?? this.variant,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        accentText: accentText ?? this.accentText,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        hairline: hairline ?? this.hairline,
        cardRadius: cardRadius ?? this.cardRadius,
        chipRadius: chipRadius ?? this.chipRadius,
        buttonRadius: buttonRadius ?? this.buttonRadius,
        cardElevation: cardElevation ?? this.cardElevation,
        usesHairline: usesHairline ?? this.usesHairline,
        chartBars: chartBars ?? this.chartBars,
        chartPeak: chartPeak ?? this.chartPeak,
        display: display ?? this.display,
        caption: caption ?? this.caption,
      );

  @override
  PetWalkTokens lerp(covariant PetWalkTokens? other, double t) {
    if (other == null) return this;
    // 테마를 바꾸면 색은 부드럽게 넘어가되 글꼴과 모양은 중간값이 의미가
    // 없으므로 절반을 넘는 순간 통째로 바뀌게 둔다.
    final flipped = t < 0.5 ? this : other;
    return PetWalkTokens(
      variant: flipped.variant,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t),
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t),
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t),
      usesHairline: flipped.usesHairline,
      chartBars: [
        for (var i = 0; i < chartBars.length; i++)
          Color.lerp(chartBars[i], other.chartBars[i], t)!,
      ],
      chartPeak: Color.lerp(chartPeak, other.chartPeak, t)!,
      display: flipped.display,
      caption: flipped.caption,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// 1a — 귀여운 안. 크림 톤 배경에 둥근 흰 카드, 살구색 포인트.
const _cozyBg = Color(0xFFFFF8F0);
const _cozyInk = Color(0xFF4A3B31);
const _cozyAccent = Color(0xFFF59A4B);

/// 1b — 세련된 안. 종이 톤 배경에 각진 면과 1px 선, 딥그린 포인트.
const _minimalBg = Color(0xFFF2F0EB);
const _minimalInk = Color(0xFF1A1A17);
const _minimalAccent = Color(0xFF1F5B3A);

ThemeData buildTheme(AppThemeVariant variant) =>
    variant == AppThemeVariant.cozy ? _cozyTheme() : _minimalTheme();

ThemeData _cozyTheme() {
  const scheme = ColorScheme.light(
    primary: _cozyAccent,
    onPrimary: _cozyBg,
    primaryContainer: Color(0xFFFDEBD8),
    onPrimaryContainer: Color(0xFFE0842E),
    secondary: Color(0xFF8FBF7F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFEFF6EC),
    onSecondaryContainer: Color(0xFF5E8C4E),
    tertiaryContainer: Color(0xFFFDEBD8),
    onTertiaryContainer: _cozyInk,
    surface: _cozyBg,
    onSurface: _cozyInk,
    surfaceContainerHighest: Color(0xFFF3EAE0),
    onSurfaceVariant: Color(0xFF8C7A6C),
    outline: Color(0xFFEADFD1),
    outlineVariant: Color(0xFFF1E7DA),
    error: Color(0xFFC0483B),
    onError: Colors.white,
    errorContainer: Color(0xFFFBE3DF),
    onErrorContainer: Color(0xFF8A2F26),
  );

  final body = GoogleFonts.gowunDodumTextTheme()
      .apply(bodyColor: _cozyInk, displayColor: _cozyInk);

  return _base(scheme, body).copyWith(
    extensions: [
      PetWalkTokens(
        variant: AppThemeVariant.cozy,
        accent: _cozyAccent,
        accentSoft: const Color(0xFFFDEBD8),
        accentText: const Color(0xFFE0842E),
        muted: const Color(0xFF8C7A6C),
        faint: const Color(0xFFBCAB9B),
        hairline: const Color(0xFFF1E7DA),
        cardRadius: 26,
        chipRadius: 999,
        buttonRadius: 999,
        cardElevation: 0,
        usesHairline: false,
        chartBars: const [
          Color(0xFFF3EAE0),
          Color(0xFFFDEBD8),
          Color(0xFFF9C68D),
        ],
        chartPeak: _cozyAccent,
        display: GoogleFonts.poorStory(color: _cozyInk, height: 1.1),
        caption: GoogleFonts.gowunDodum(
          fontSize: 13,
          color: const Color(0xFFA2907F),
        ),
      ),
    ],
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      // 그림자를 Card elevation 대신 색으로 넣는다. Material3 의 기본
      // elevation 색조가 크림 톤 위에서 탁하게 보인다.
      shadowColor: const Color(0x144A3B31),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _cozyInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poorStory(fontSize: 32, color: _cozyInk),
    ),
  );
}

ThemeData _minimalTheme() {
  const scheme = ColorScheme.light(
    primary: _minimalInk,
    onPrimary: _minimalBg,
    primaryContainer: Color(0xFFE4EBDC),
    onPrimaryContainer: _minimalAccent,
    secondary: _minimalAccent,
    onSecondary: _minimalBg,
    secondaryContainer: Color(0xFFE4EBDC),
    onSecondaryContainer: _minimalAccent,
    tertiaryContainer: Color(0xFFE4EBDC),
    onTertiaryContainer: _minimalInk,
    surface: _minimalBg,
    onSurface: _minimalInk,
    surfaceContainerHighest: Color(0xFFE7E4DC),
    onSurfaceVariant: Color(0xFF6E6A61),
    outline: Color(0xFFE2DFD7),
    outlineVariant: Color(0xFFE2DFD7),
    error: Color(0xFF8C2F22),
    onError: Colors.white,
    errorContainer: Color(0xFFEDE0DC),
    onErrorContainer: Color(0xFF6B241A),
  );

  final body = GoogleFonts.ibmPlexSansKrTextTheme()
      .apply(bodyColor: _minimalInk, displayColor: _minimalInk);

  return _base(scheme, body).copyWith(
    extensions: [
      PetWalkTokens(
        variant: AppThemeVariant.minimal,
        accent: _minimalAccent,
        accentSoft: const Color(0xFFE4EBDC),
        accentText: _minimalAccent,
        muted: const Color(0xFF6E6A61),
        faint: const Color(0xFF9A968C),
        hairline: const Color(0xFFE2DFD7),
        cardRadius: 16,
        chipRadius: 6,
        buttonRadius: 16,
        cardElevation: 0,
        usesHairline: true,
        chartBars: const [
          Color(0xFFE2DFD7),
          Color(0xFFD6D2C8),
          Color(0xFFA9B79F),
        ],
        chartPeak: _minimalAccent,
        display: GoogleFonts.blackHanSans(color: _minimalInk, height: 1.05),
        caption: GoogleFonts.ibmPlexMono(
          fontSize: 10,
          letterSpacing: 1.2,
          color: const Color(0xFF6E6A61),
        ),
      ),
    ],
    cardTheme: CardThemeData(
      color: _minimalBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2DFD7)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _minimalInk,
      elevation: 0,
      centerTitle: false,
      // Black Han Sans 는 weight 가 하나뿐이라 400 으로 둬야 한다.
      // w700 을 주면 합성 볼드가 끼어들어 지저분해진다.
      titleTextStyle: GoogleFonts.blackHanSans(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        color: _minimalInk,
      ),
    ),
  );
}

/// 두 안이 공유하는 뼈대. 색과 글꼴만 인자로 받는다.
ThemeData _base(ColorScheme scheme, TextTheme body) {
  final radius = scheme.primary == _cozyAccent ? 999.0 : 16.0;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: body,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: scheme.onSurface),
        foregroundColor: scheme.onSurface,
        textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:
          scheme.primary == _cozyAccent ? Colors.white : scheme.surface,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        body.labelMedium?.copyWith(fontSize: 13),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(scheme.primary == _cozyAccent ? 999 : 6),
      ),
    ),
  );
}
