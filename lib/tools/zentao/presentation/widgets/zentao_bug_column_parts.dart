import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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
