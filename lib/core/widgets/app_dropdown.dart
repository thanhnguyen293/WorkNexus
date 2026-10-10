import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The app's dropdown picker, filling its width: the current choice with a caret, and a
/// menu of [values] that checks the picked one. [fontFamilyOf] lets a choice
/// preview itself (the font picker renders each font in its own face).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.tooltip,
    this.fontFamilyOf,
    super.key,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final String? tooltip;
  final String? Function(BuildContext context, T value)? fontFamilyOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: tooltip,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.md),
        side: context.hairlineSide,
      ),
      itemBuilder: (context) => [
        for (final option in values)
          PopupMenuItem<T>(
            value: option,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelOf(option),
                    style: context.typography.subtitle.copyWith(
                      fontFamily: fontFamilyOf?.call(context, option),
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (option == value)
                  Icon(LucideIcons.check300, color: c.accent),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          border: context.cardBorder,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelOf(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySmStrong.copyWith(
                  fontFamily: fontFamilyOf?.call(context, value),
                  color: c.textPrimary,
                ),
              ),
            ),
            SizedBox(width: context.spacing.xs),
            Icon(
              LucideIcons.chevronDown300,
              size: context.spacing.xl3,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
