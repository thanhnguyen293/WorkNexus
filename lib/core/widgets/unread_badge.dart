import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Accent pill with an unread count (capped at 99+).
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.typography.captionSm.copyWith(
          color: c.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
