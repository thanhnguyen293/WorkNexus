import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_check_mark.dart';
import '../../../../core/widgets/hover_surface.dart';

/// A tickable row of the "Thầy vô" lists (apps to open, allowed senders): the
/// whole row toggles, and shows a rounded, outlined tint on hover. [leading]
/// is an avatar or an app icon. When not [enabled] it only shows [picked].
class PanicCheckRow extends StatelessWidget {
  const PanicCheckRow({
    super.key,
    required this.label,
    required this.picked,
    required this.onToggle,
    this.detail,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final String? detail;
  final Widget? leading;
  final bool picked;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    final leading = this.leading;
    final detail = this.detail;
    return HoverSurface(
      onTap: enabled ? onToggle : null,
      enabled: enabled,
      borderRadius: radius,
      border: Border.all(color: Colors.transparent),
      hoverBorder: Border.all(color: c.border),
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.md),
      child: Row(
        spacing: s.md,
        children: [
          AppCheckMark(checked: picked, enabled: enabled),
          ?leading,
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body.copyWith(
                color: enabled ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
          if (detail != null)
            Text(
              detail,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
        ],
      ),
    );
  }
}
