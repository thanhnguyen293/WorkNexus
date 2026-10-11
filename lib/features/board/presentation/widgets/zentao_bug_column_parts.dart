import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_column.dart';

/// A ZenTao bug column's header label and status-dot colour.
(String, Color) bugColumnVisual(BuildContext context, ZenTaoBugColumn column) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return switch (column) {
    ZenTaoBugColumn.newUnconfirmed => (l.boardBugColNew, c.textTertiary),
    ZenTaoBugColumn.confirmedToFix => (l.boardBugColConfirmed, c.accent),
    ZenTaoBugColumn.resolvedVerify => (l.boardBugColResolved, c.success),
    ZenTaoBugColumn.postponed => (l.boardBugColPostponed, c.warning),
    ZenTaoBugColumn.nonFix => (l.boardBugColNonFix, c.error),
    ZenTaoBugColumn.closed => (l.boardBugColClosed, c.textSecondary),
  };
}

/// The column's ticket count; a trailing "+" while it can load more.
class BugColumnCount extends StatelessWidget {
  const BugColumnCount(this.count, {super.key, this.more = false});

  final int count;
  final bool more;

  @override
  Widget build(BuildContext context) {
    if (!more) return AppCountBadge(count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.spacing.xxs,
      children: [
        AppCountBadge(count),
        Text(
          '+',
          style: context.typography.monoXs.copyWith(
            color: context.colors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The tilted card shown under the cursor while dragging a bug ticket.
class BugCardDragFeedback extends StatelessWidget {
  const BugCardDragFeedback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // A card's width inside a column (the list's side padding removed).
        width: context.sizes.boardColumn - context.spacing.xl2,
        child: Transform.rotate(angle: -0.01, child: child),
      ),
    );
  }
}
