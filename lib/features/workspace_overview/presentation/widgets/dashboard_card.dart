import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';

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
    // A Material rather than a decorated Container, so the rows' InkWell
    // hover and splash paint on the card instead of under it.
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: context.hairlineSide,
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
                    Icon(
                      icon,
                      size: context.sizes.iconMd,
                      color: c.textSecondary,
                    ),
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
                    AppCountBadge(n),
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
