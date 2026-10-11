import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// The one label style for the sources tree's group rows (Pinned, Bugs,
/// Tasks, Projects, Repositories), so every group reads at the same level.
TextStyle sidebarGroupLabelStyle(BuildContext context) => context
    .typography
    .mono
    .copyWith(fontWeight: FontWeight.w600, color: context.colors.textSecondary);

/// A collapsible group row in the sources tree: a chevron, an optional
/// [icon], the [label] and an optional trailing [count]. [labelStyle]
/// overrides the group style for rows that are items themselves (a project
/// holding executions).
class SidebarGroupToggle extends StatelessWidget {
  const SidebarGroupToggle({
    super.key,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.icon,
    this.count,
    this.labelStyle,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final icon = this.icon;
    final count = this.count;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        height: context.sizes.controlSm,
        padding: EdgeInsets.symmetric(horizontal: s.sm),
        child: Row(
          children: [
            Icon(
              expanded
                  ? LucideIcons.chevronDown300
                  : LucideIcons.chevronRight300,
              size: context.sizes.iconSm,
              color: c.textTertiary,
            ),
            SizedBox(width: s.xs),
            if (icon != null) ...[
              Icon(icon, size: context.sizes.iconSm, color: c.textTertiary),
              SizedBox(width: s.sm),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle ?? sidebarGroupLabelStyle(context),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: context.typography.monoXs.copyWith(
                  color: c.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tree row that stands in for children not shown: still loading
/// ([loading]), none there, or a failed load ([isError], with a retry when
/// [onRetry] is given) — a failure must not look like an empty group.
class SidebarStatusRow extends StatelessWidget {
  const SidebarStatusRow({
    super.key,
    required this.label,
    this.loading = false,
    this.isError = false,
    this.onRetry,
  });

  final String label;
  final bool loading;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final ink = isError ? c.error : c.textTertiary;
    final retry = onRetry;
    final Widget leading;
    if (loading) {
      leading = SizedBox.square(
        dimension: context.sizes.iconXs,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: ink),
      );
    } else if (isError) {
      leading = Icon(
        LucideIcons.circleAlert300,
        size: context.sizes.iconXs,
        color: ink,
      );
    } else {
      leading = Container(
        width: s.xs,
        height: s.xs,
        decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
      );
    }
    return Container(
      height: context.sizes.controlSm,
      padding: EdgeInsets.only(left: s.sm),
      child: Row(
        children: [
          leading,
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ),
          if (retry != null)
            AppIconButton(
              icon: LucideIcons.rotateCw300,
              tooltip: AppL10n.of(context).retry,
              size: AppIconButtonSize.small,
              onPressed: retry,
            ),
        ],
      ),
    );
  }
}
