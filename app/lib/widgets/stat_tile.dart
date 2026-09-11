import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 거리·시간·페이스처럼 큰 수치 하나를 라벨과 함께 보여 준다.
///
/// 수치 글꼴을 테마 토큰에서 가져오는 게 핵심이다. 두 안의 인상 차이가
/// 대부분 여기서 갈린다 — 1a 는 손글씨, 1b 는 초굵은 고딕.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.alignment = CrossAxisAlignment.center,
  });

  final String label;
  final String value;
  final bool emphasize;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final tokens = PetWalkTokens.of(context);
    final minimal = tokens.variant == AppThemeVariant.minimal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          value,
          style: tokens.display.copyWith(
            fontSize: emphasize ? 30 : 22,
            // 숫자가 1초마다 바뀌는 자리라 폭이 고정돼야 흔들리지 않는다.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // 1b 는 캡션이 모노스페이스 대문자다. 한글 라벨은 그대로 두고
          // 크기와 자간만 캡션 토큰을 따른다.
          label,
          style: minimal
              ? tokens.caption.copyWith(fontSize: 11)
              : tokens.caption,
        ),
      ],
    );
  }
}
