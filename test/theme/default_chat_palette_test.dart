import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/theme/chat_style_palette.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final variant in AppThemeVariant.values) {
    test('default chat colours read at 4.5:1 (${variant.name})', () {
      final c = buildAppTheme(
        variant: variant,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ).extension<AppColors>()!;
      final p = ChatStylePalette.fromTheme(c);
      // Fills may be translucent: compare against what is on screen.
      final incoming = Color.alphaBlend(p.incomingBubble, p.background);
      final own = Color.alphaBlend(p.outgoingBubble, p.background);
      final incomingCard = Color.alphaBlend(p.quoteFill!, incoming);
      final ownCard = Color.alphaBlend(p.outgoingQuoteFill!, own);
      final cases = {
        'incoming text': (p.incomingText, incoming),
        'incoming meta': (p.incomingMeta, incoming),
        'incoming card meta': (p.incomingMeta, incomingCard),
        'incoming card link': (p.incomingLink, incomingCard),
        'own text': (p.outgoingText, own),
        'own meta': (p.outgoingMeta, own),
        'own link': (p.outgoingLink, own),
        'own card meta': (p.outgoingMeta, ownCard),
        'own card link': (p.outgoingLink, ownCard),
      };
      for (final MapEntry(:key, value: (ink, fill)) in cases.entries) {
        expect(_contrast(ink, fill), greaterThanOrEqualTo(4.5), reason: key);
      }
    });
  }
}
