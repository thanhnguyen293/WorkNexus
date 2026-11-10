import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/zentao_doc_providers.dart';

/// The document reader's page: the app's own theme, or — when the reader is
/// switched to the other brightness — the app theme rebuilt in that variant
/// (same font, density, radius and accent), so only the page changes.
///
/// The page sits on the `card` surface, the lightest one in light mode, so
/// code blocks and table headers (`surfaceSubtle`) stand off it in both.
class ZenTaoDocReaderTheme extends ConsumerWidget {
  const ZenTaoDocReaderTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(zentaoDocReaderBrightnessProvider);
    final page = Builder(
      builder: (context) =>
          ColoredBox(color: context.colors.card, child: child),
    );
    if (forced == null || forced == Theme.of(context).brightness) return page;

    final a = ref.watch(
      appSettingsProvider.select(
        (s) => (
          surface: s.surface,
          density: s.density,
          fontFamily: s.fontFamily,
          componentRadius: s.componentRadius,
          accentColorValue: s.accentColorValue,
        ),
      ),
    );
    return Theme(
      data: buildAppTheme(
        variant: forced == Brightness.light
            ? AppThemeVariant.light
            : AppThemeVariant.dark,
        surface: a.surface,
        density: a.density,
        fontFamily: a.fontFamily,
        componentRadius: a.componentRadius,
        accentColorValue: a.accentColorValue,
      ),
      child: page,
    );
  }
}
