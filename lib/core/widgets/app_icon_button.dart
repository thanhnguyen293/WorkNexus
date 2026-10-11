import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';

/// Icon-only button sizes: the square hit target and the glyph inside it.
enum AppIconButtonSize { small, medium }

/// The app's icon-only button: a square, rounded, flat target with the hover /
/// focus / press layers of the button theme, a required [tooltip] (its
/// accessible name), an optional [selected] state and an [isLoading] spinner
/// that keeps the footprint.
///
/// `small` (28px, 14px glyph) sits in dense rows and chips; `medium` (32px,
/// 16px glyph) in toolbars and headers.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AppIconButtonSize.medium,
    this.selected = false,
    this.isLoading = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonSize size;
  final bool selected;
  final bool isLoading;

  /// Overrides the resting glyph colour (e.g. `colors.error` for a delete).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sizes = context.sizes;
    final (box, glyph) = switch (size) {
      AppIconButtonSize.small => (sizes.controlSm, sizes.iconSm),
      AppIconButtonSize.medium => (sizes.controlMd, sizes.iconMd),
    };
    final ink = selected ? c.accent : color ?? c.textSecondary;
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      onPressed: isLoading ? null : onPressed,
      iconSize: glyph,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: box, height: box),
      style: ButtonStyle(
        mouseCursor: WidgetStateMouseCursor.clickable,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
          ),
        ),
        backgroundColor: WidgetStatePropertyAll(
          selected ? c.selectionFill : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) && !isLoading
              ? c.textTertiary.withValues(alpha: 0.6)
              : states.contains(WidgetState.hovered) && !selected
              ? (color ?? c.textPrimary)
              : ink,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? c.textPrimary.withValues(alpha: 0.12)
              : states.contains(WidgetState.focused)
              ? c.accent.withValues(alpha: 0.16)
              : states.contains(WidgetState.hovered)
              ? c.hoverFill
              : null,
        ),
      ),
      icon: isLoading
          ? SizedBox.square(
              dimension: glyph,
              child: CircularProgressIndicator(color: c.textTertiary),
            )
          : Icon(icon),
    );
  }
}
