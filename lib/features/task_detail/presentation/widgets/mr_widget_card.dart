import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The shell of a GitLab-style merge-request widget (approvals, merge,
/// merged / closed): a status icon, a one-line [title] and its [actions], over
/// an optional inset [details] block.
class MrWidgetCard extends StatelessWidget {
  const MrWidgetCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.actions = const [],
    this.details,
    this.tint,
  });

  final IconData icon;
  final Color iconColor;
  final Widget title;
  final List<Widget> actions;
  final Widget? details;

  /// Washes the header row in this colour (the merged state's blue band).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tint = this.tint;
    final details = this.details;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tint == null ? null : c.mixT(tint, 0.08),
            padding: EdgeInsets.all(s.lg),
            child: Row(
              children: [
                Icon(icon, size: context.sizes.iconLg, color: iconColor),
                SizedBox(width: s.md),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                    child: title,
                  ),
                ),
                for (final action in actions) ...[
                  SizedBox(width: s.sm),
                  action,
                ],
              ],
            ),
          ),
          if (details != null)
            Container(
              padding: EdgeInsets.all(s.lg),
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                border: Border(top: context.hairlineSide),
              ),
              child: DefaultTextStyle.merge(
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                ),
                child: details,
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of a widget's details block, bulleted.
class MrDetailBullet extends StatelessWidget {
  const MrDetailBullet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•'),
          SizedBox(width: context.spacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}
