import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The tab row at the top of a chat panel (emoji/stickers, files), over a
/// hairline, for the [DefaultTabController] above it. [height], when given,
/// is the row's height with its border — beside the chat it matches the
/// pinned-message bar; otherwise it is as tall as the app's other tab rows,
/// not Material's 46. [action] sits at the end of the row.
class ChatPanelTabBar extends StatelessWidget {
  const ChatPanelTabBar({
    super.key,
    required this.labels,
    this.height,
    this.action,
  });

  final List<String> labels;
  final double? height;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final rowHeight = height;
    final tabHeight = rowHeight == null
        ? context.sizes.controlMd + s.md
        : rowHeight - context.borders.hairline;
    final action = this.action;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              labelStyle: context.typography.bodySmStrong,
              unselectedLabelStyle: context.typography.bodySm,
              dividerColor: Colors.transparent,
              tabs: [
                for (final label in labels) Tab(height: tabHeight, text: label),
              ],
            ),
          ),
          if (action != null) ...[
            VerticalDivider(width: 1, color: context.colors.border),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xs),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}
