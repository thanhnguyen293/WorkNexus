import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// One line of a dashboard list: [leading], a title over an optional
/// [subtitle], and [trailing] chips. Hover-highlighted and clickable when
/// [onTap] is set.
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing = const [],
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final subtitle = this.subtitle;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      hoverColor: c.selectionFill,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.sm),
        child: Row(
          children: [
            if (leading != null) ...[leading!, SizedBox(width: s.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: c.textPrimary),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: c.textTertiary),
                    ),
                ],
              ),
            ),
            for (final w in trailing) ...[SizedBox(width: s.sm), w],
          ],
        ),
      ),
    );
  }
}
