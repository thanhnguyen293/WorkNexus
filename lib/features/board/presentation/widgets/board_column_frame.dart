import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// One kanban column's chrome, shared by every board: a header (status [dot],
/// [label], count [badge]) over the scrolling cards. A column with no items
/// says so instead of standing blank. [highlighted] tints it while a dragged
/// card hovers over it.
class BoardColumnFrame extends StatelessWidget {
  const BoardColumnFrame({
    super.key,
    required this.dot,
    required this.label,
    required this.badge,
    required this.itemCount,
    required this.itemBuilder,
    this.highlighted = false,
  });

  final Widget dot;
  final String label;
  final Widget badge;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: context.sizes.boardColumn,
      decoration: BoxDecoration(
        color: highlighted ? c.selectionFill : c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: context.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(s.xl, s.xl, s.xl, s.md),
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
              ],
            ),
          ),
          if (itemCount == 0)
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, s.xs, s.xl, s.xl2),
              child: Text(
                AppL10n.of(context).noItems,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                key: PageStorageKey('board-column-$label'),
                padding: EdgeInsets.fromLTRB(s.sm, s.xxs, s.sm, s.md),
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
