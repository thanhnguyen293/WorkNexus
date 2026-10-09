import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A dashboard section in the app's panel-card style (like the chat info
/// cards): a surface with a hairline border, a header with an optional icon,
/// count and action, then [child].
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.count,
    this.action,
    this.padding,
  });

  final String? title;
  final IconData? icon;
  final int? count;

  /// A compact trailing button, e.g. "See all".
  final Widget? action;

  /// Padding around [child]; lists pass a tighter one so rows reach the edge.
  final EdgeInsets? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final title = this.title;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, s.xl, s.md, 0),
              child: Row(
                children: [
                  if (icon case final icon?) ...[
                    Icon(icon, size: s.xl3, color: c.textSecondary),
                    SizedBox(width: s.md),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (count case final n?) ...[
                    SizedBox(width: s.sm),
                    DashboardCountBadge(n),
                  ],
                  const Spacer(),
                  ?action,
                ],
              ),
            ),
          Padding(padding: padding ?? EdgeInsets.all(s.xl), child: child),
        ],
      ),
    );
  }
}

/// A muted pill holding a count, beside a section title.
class DashboardCountBadge extends StatelessWidget {
  const DashboardCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs / 2),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        '$count',
        style: context.typography.captionStrong.copyWith(
          color: c.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The compact text button for a card header ("See all").
class DashboardCardAction extends StatelessWidget {
  const DashboardCardAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    child: Text(label),
  );
}
