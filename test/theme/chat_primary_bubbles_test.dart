import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/theme/chat_style_palette.dart';

double _contrast(Color a, Color b) {
  final (hi, lo) = a.computeLuminance() > b.computeLuminance()
      ? (a.computeLuminance(), b.computeLuminance())
      : (b.computeLuminance(), a.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

AppColors _colors(AppThemeVariant variant) => buildAppTheme(
  variant: variant,
  surface: SurfaceStyle.outline,
  density: AppDensity.comfortable,
).extension<AppColors>()!;

void main() {
  final cases = [
    (AppThemeVariant.light, ChatStylePalette.zaloLight),
    (AppThemeVariant.light, ChatStylePalette.telegramDay),
    (AppThemeVariant.light, ChatStylePalette.wechatLight),
    (AppThemeVariant.light, ChatStylePalette.zentaoLight),
    (AppThemeVariant.light, ChatStylePalette.tbchatLight),
    (AppThemeVariant.dark, ChatStylePalette.zaloDark),
    (AppThemeVariant.dark, ChatStylePalette.telegramNight),
    (AppThemeVariant.dark, ChatStylePalette.wechatDark),
    (AppThemeVariant.dark, ChatStylePalette.zentaoDark),
    (AppThemeVariant.dark, ChatStylePalette.tbchatDark),
  ];

  test('accent bubbles keep message text readable (≥ 4.5:1)', () {
    for (final (variant, palette) in cases) {
      final c = _colors(variant);
      final p = palette.withPrimaryBubbles(
        c,
        dark: variant == AppThemeVariant.dark,
      );
      expect(
        _contrast(p.outgoingText, p.outgoingBubble),
        greaterThanOrEqualTo(4.5),
        reason: '$variant',
      );
    }
  });

  test('only own bubbles change', () {
    final c = _colors(AppThemeVariant.light);
    const base = ChatStylePalette.zentaoLight;
    final p = base.withPrimaryBubbles(c, dark: false);
    // An accent tint over the incoming bubble, under the style's own ink.
    expect(
      p.outgoingBubble,
      Color.alphaBlend(c.accent.withValues(alpha: 0.16), base.incomingBubble),
    );
    expect(p.outgoingText, base.incomingText);
    expect(p.outgoingLink, c.accent);
    expect(p.incomingBubble, base.incomingBubble);
    expect(p.background, base.background);
  });
}
