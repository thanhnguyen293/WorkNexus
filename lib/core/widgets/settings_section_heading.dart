import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The heading over a settings section: a title, a one-paragraph explanation
/// and an optional action on the right.
class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.typography.titleLg.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: s.xs),
              Text(
                subtitle,
                style: context.typography.paragraph.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: s.xl3), trailing],
      ],
    );
  }
}
