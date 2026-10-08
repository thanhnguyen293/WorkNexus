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
    (AppThemeVariant.light, ChatStylePalette.zaloLight, false),
    (AppThemeVariant.light, ChatStylePalette.telegramDay, false),
    (AppThemeVariant.light, ChatStylePalette.wechatLight, false),
    (AppThemeVariant.light, ChatStylePalette.messengerLight, true),
    (AppThemeVariant.dark, ChatStylePalette.zaloDark, false),
    (AppThemeVariant.dark, ChatStylePalette.telegramNight, false),
    (AppThemeVariant.dark, ChatStylePalette.wechatDark, false),
    (AppThemeVariant.dark, ChatStylePalette.messengerDark, true),
  ];

  test('accent bubbles keep message text readable (≥ 4.5:1)', () {
    for (final (variant, palette, solid) in cases) {
      final c = _colors(variant);
      final p = palette.withPrimaryBubbles(
        c,
        solid: solid,
        dark: variant == AppThemeVariant.dark,
      );
      expect(
        _contrast(p.outgoingText, p.outgoingBubble),
        greaterThanOrEqualTo(4.5),
        reason: '$variant solid=$solid',
      );
    }
  });

  test('only own bubbles change', () {
    final c = _colors(AppThemeVariant.light);
    const base = ChatStylePalette.messengerLight;
    final p = base.withPrimaryBubbles(c, solid: true, dark: false);
    // The light theme's accent already reads well under its ink.
    expect(p.outgoingBubble, c.accent);
    expect(p.outgoingText, c.onAccent);
    expect(p.incomingBubble, base.incomingBubble);
    expect(p.background, base.background);
  });
}
