import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// "How it works" at the top of a tab: a few short steps, each with an icon,
/// filled in with the user's own settings.
class PanicSteps extends StatelessWidget {
  const PanicSteps({super.key, required this.title, required this.steps});

  final String title;
  final List<(IconData, String)> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.lg),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: s.md,
        children: [
          Text(
            title,
            style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
          ),
          for (final (icon, text) in steps)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: s.md,
              children: [
                Icon(icon, size: context.sizes.iconSm, color: c.accent),
                Expanded(
                  child: Text(
                    text,
                    style: context.typography.paragraph.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
