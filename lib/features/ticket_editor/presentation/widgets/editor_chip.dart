import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A small removable chip — an attached file, a picked build or user — in
/// the app's quiet chip style instead of Material's outlined one.
class EditorChip extends StatelessWidget {
  const EditorChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.icon,
    this.maxWidth,
  });

  final String label;
  final VoidCallback onRemove;
  final IconData? icon;

  /// Caps long file names.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.bodySm.copyWith(color: c.textPrimary),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(s.md, s.xxs, s.xxs, s.xxs),
      decoration: BoxDecoration(
        color: c.mixT(c.accent, 0.08),
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.mixT(c.accent, 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: s.xl, color: c.accent),
            SizedBox(width: s.xs),
          ],
          if (maxWidth case final w?)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w),
              child: text,
            )
          else
            Flexible(child: text),
          SizedBox(width: s.xxs),
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: onRemove,
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Padding(
              padding: EdgeInsets.all(s.xs),
              child: Icon(
                PhosphorIconsLight.x,
                size: s.xl,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
