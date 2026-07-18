import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A row of color swatches for choosing the app primary color. The first swatch
/// ("default") clears the override and follows the theme variant's accent.
class QuickSettingsColorControl extends ConsumerWidget {
  const QuickSettingsColorControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final selected = settings.accentColorValue;
    final defaultColor = AppPalette.of(settings.variant).accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.primaryColor,
          style: context.typography.caption.copyWith(color: c.textTertiary),
        ),
        SizedBox(height: context.spacing.sm),
        Wrap(
          spacing: context.spacing.xs,
          runSpacing: context.spacing.xs,
          children: [
            _Swatch(
              color: defaultColor,
              selected: selected == null,
              tooltip: l.colorDefault,
              onTap: () => controller.setAccentColor(null),
            ),
            for (final value in kAccentPresets)
              _Swatch(
                color: Color(value),
                selected: selected == value,
                onTap: () => controller.setAccentColor(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final swatch = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: c.mixT(c.scrim, 0.12)),
          ),
        ),
      ),
    );
    return tooltip == null ? swatch : Tooltip(message: tooltip!, child: swatch);
  }
}
