import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_count_badge.dart';

/// The small uppercase label that opens a group of rows or fields (a sidebar
/// group, a settings section, a day in a feed), with an optional [count] and a
/// [trailing] action on the right. One style for every such label.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.padding,
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = this.count;
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.sizes.controlSm),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.labelWide.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ),
            if (count != null) ...[
              SizedBox(width: context.spacing.sm),
              AppCountBadge(count),
            ],
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
