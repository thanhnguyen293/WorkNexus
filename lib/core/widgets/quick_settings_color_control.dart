import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'custom_color_dialog.dart';
import 'hover_surface.dart';

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
            _Swatch(
              size: size,
              color: defaultColor,
              selected: selected == null,
              tooltip: l.colorDefault,
              onTap: () => controller.setAccentColor(null),
            ),
            for (final value in kAccentPresets)
              _Swatch(
                size: size,
                color: Color(value),
                selected: selected == value,
                onTap: () => controller.setAccentColor(value),
              ),
            _Swatch(
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

/// One round swatch; with no [color] it's the "pick your own" button.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.size,
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final double size;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = this.color;
    // A 2px ring, then a 1.5px gap, around the dot.
    const ring = 2.0;
    const ringGap = 1.5;
    final swatch = HoverSurface(
      onTap: onTap,
      shape: BoxShape.circle,
      width: size,
      height: size,
      padding: const EdgeInsets.all(ringGap),
      // The ring answers hover, not a tint: a tint would shift the colour.
      tintOnHover: false,
      border: Border.all(
        color: selected ? c.textPrimary : Colors.transparent,
        width: ring,
      ),
      hoverBorder: Border.all(
        color: selected ? c.textPrimary : c.borderStrong,
        width: ring,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? c.surfaceSubtle,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == null ? c.borderStrong : c.mixT(c.scrim, 0.12),
          ),
        ),
        child: color == null
            ? Icon(
                PhosphorIconsLight.plus,
                size: size * 0.45,
                color: c.textSecondary,
              )
            : const SizedBox.expand(),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null ? swatch : Tooltip(message: tooltip, child: swatch);
  }
}
