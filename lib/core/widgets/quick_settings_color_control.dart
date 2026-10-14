import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'custom_color_dialog.dart';
import 'swatch_button.dart';

/// Swatches per row: default + 20 presets + custom fill two even rows.
const int _kColumns = 11;

/// The app primary colour: the theme's own accent ("default"), the presets,
/// and a last swatch that opens a free picker — showing the custom colour
/// once one is chosen.
class QuickSettingsColorControl extends ConsumerWidget {
  const QuickSettingsColorControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final selected = ref.watch(
      appSettingsProvider.select((st) => st.accentColorValue),
    );
    final controller = ref.read(appSettingsProvider.notifier);
    // The variant actually on screen (following the OS, it's light or dark).
    final defaultColor = AppPalette.of(
      Theme.of(context).brightness == Brightness.dark
          ? AppThemeVariant.dark
          : AppThemeVariant.light,
    ).accent;
    final custom = selected != null && !kAccentPresets.contains(selected)
        ? selected
        : null;

    Future<void> pickCustom() async {
      final picked = await showCustomColorDialog(
        context,
        initial: Color(selected ?? defaultColor.toARGB32()),
      );
      if (picked != null) controller.setAccentColor(picked);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final gap = s.xs;
        final size = (box.maxWidth - gap * (_kColumns - 1)) / _kColumns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SwatchButton(
              size: size,
              color: defaultColor,
              selected: selected == null,
              tooltip: l.colorDefault,
              onTap: () => controller.setAccentColor(null),
            ),
            for (final value in kAccentPresets)
              SwatchButton(
                size: size,
                color: Color(value),
                selected: selected == value,
                onTap: () => controller.setAccentColor(value),
              ),
            SwatchButton(
              size: size,
              color: custom == null ? null : Color(custom),
              selected: custom != null,
              tooltip: l.colorCustom,
              onTap: pickCustom,
            ),
          ],
        );
      },
    );
  }
}
