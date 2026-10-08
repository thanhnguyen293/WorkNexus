import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/settings/chat_appearance.dart';
import 'package:work_nexus/core/theme/app_colors.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/theme/contrast.dart';
import 'package:work_nexus/core/theme/semantic.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_style.dart';

/// Link cards and quotes sit on a tint inside the bubble; their text and
/// the app's state colours (merged, open, +/−, priority) must read on it in
/// every chat style, theme and bubble side.
void main() {
  for (final variant in AppThemeVariant.values) {
    testWidgets('card text reads at 4.5:1 in every style (${variant.name})', (
      tester,
    ) async {
      final failures = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            themeAnimationDuration: Duration.zero,
            theme: buildAppTheme(
              variant: variant,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            home: Builder(
              builder: (context) {
                final c = context.colors;
                final states = {
                  'info': c.info,
                  'success': c.success,
                  'error': c.error,
                  'warning': c.warning,
                  for (final p in Priority.values)
                    'priority ${p.name}': priorityColor(c, p),
                };
                for (final appearance in ChatAppearance.values) {
                  for (final primary in [false, true]) {
                    final style = ChatStyle.of(
                      appearance,
                      context,
                      primaryBubbles: primary,
                    );
                    // Date separators on the shared chat background.
                    final p = style.palette;
                    final separatorBack =
                        style.separator == ChatSeparatorStyle.pill
                        ? Color.alphaBlend(
                            p.separatorFill ?? p.background,
                            p.background,
                          )
                        : p.background;
                    if (contrastRatio(p.separatorText, separatorBack) < 4.5) {
                      failures.add('${appearance.name}: separator');
                    }
                    for (final mine in [false, true]) {
                      final ink = style.ink(mine: mine);
                      final surface = ink.quoteSurface;
                      final where =
                          '${appearance.name}${primary ? '+accent' : ''} '
                          '${mine ? 'own' : 'incoming'}';
                      if (contrastRatio(ink.text, surface) < 4.5) {
                        failures.add('$where: text');
                      }
                      for (final MapEntry(:key, :value) in {
                        'meta': ink.meta,
                        'link': ink.link,
                        'quote name': ink.quoteBar,
                        ...states,
                      }.entries) {
                        final shown = readableOn(
                          value,
                          surface,
                          towards: ink.text,
                        );
                        if (contrastRatio(shown, surface) < 4.5) {
                          failures.add('$where: $key');
                        }
                      }
                    }
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(failures, isEmpty);
    });
  }
}
