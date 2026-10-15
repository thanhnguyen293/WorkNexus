import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Renders a placeholder empty state for unbuilt / unavailable sections or views,
/// showing an icon tile, title, descriptive body, and an optional action button
/// (e.g. "Switch to List").
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final sizes = context.sizes;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: sizes.stateMessage),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sizes.stateTile,
                height: sizes.stateTile,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(radii.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: sizes.iconXl,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: typography.title.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                body,
                textAlign: TextAlign.center,
                style: typography.paragraph.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: spacing.lg),
                AppButton.outlinedNeutral(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
