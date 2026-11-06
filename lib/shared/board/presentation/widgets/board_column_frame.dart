import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'board_column_empty_slot.dart';

/// One kanban column's chrome, shared by every board: a structured header
/// (status [dot], [label], count [badge], hairline divider) over the scrolling
/// cards. A column with no items renders an intentional [BoardColumnEmptySlot].
/// [highlighted] tints the frame while a dragged card hovers over it.
class BoardColumnFrame extends StatelessWidget {
  const BoardColumnFrame({
    super.key,
    required this.dot,
    required this.label,
    required this.badge,
    required this.itemCount,
    required this.itemBuilder,
    this.highlighted = false,
    this.onFold,
  });

  final Widget dot;
  final String label;
  final Widget badge;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool highlighted;

  /// Folds the column to a strip (see `BoardFoldedColumn`); no fold button
  /// without it.
  final VoidCallback? onFold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final border = highlighted
        ? Border.all(color: c.accent, width: context.borders.hairline)
        : context.cardBorder;

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: Curves.easeOut,
      width: context.sizes.boardColumn,
      decoration: BoxDecoration(
        color: highlighted ? c.selectionFill : c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(s.xl, s.lg, s.xl, s.md),
            decoration: BoxDecoration(
              border: Border(bottom: context.hairlineSide),
            ),
            child: Row(
              children: [
                dot,
                SizedBox(width: s.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: s.md),
                badge,
                if (onFold case final fold?) ...[
                  SizedBox(width: s.xs),
                  AppIconButton(
                    icon: LucideIcons.chevronsLeft300,
                    tooltip: AppL10n.of(context).boardFoldColumn,
                    size: AppIconButtonSize.small,
                    onPressed: fold,
                  ),
                ],
              ],
            ),
          ),
          if (itemCount == 0)
            Expanded(child: BoardColumnEmptySlot(highlighted: highlighted))
          else
            Flexible(
              child: ListView.separated(
                key: PageStorageKey('board-column-$label'),
                padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.md),
                itemCount: itemCount,
                itemBuilder: itemBuilder,
                separatorBuilder: (_, _) => SizedBox(height: s.md),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small status dot at the leading edge of a column header.
class BoardColumnDot extends StatelessWidget {
  const BoardColumnDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = context.spacing.md;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
