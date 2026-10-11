import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A neutral count pill (a column's ticket count, a tab's item count). [active]
/// tints it with the accent, for the count on a selected tab. Unread counts
/// that demand attention use `UnreadBadge` instead.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge(this.count, {super.key, this.active = false});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: active ? c.mixT(c.accent, 0.14) : c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: context.typography.monoXs.copyWith(
          color: active ? c.accent : c.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
