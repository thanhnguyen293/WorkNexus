import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/value_objects/zentao_bug_column.dart';

/// Small status dot shown at the leading edge of a ZenTao bug column header.
class BugColumnDot extends StatelessWidget {
  const BugColumnDot(this.column, {super.key});

  final ZenTaoBugColumn column;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (column) {
      ZenTaoBugColumn.newUnconfirmed => c.textTertiary,
      ZenTaoBugColumn.confirmedToFix => c.accent,
      ZenTaoBugColumn.resolvedVerify => c.success,
      ZenTaoBugColumn.postponed => c.warning,
      ZenTaoBugColumn.nonFix => c.error,
      ZenTaoBugColumn.closed => c.textSecondary,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Ticket-count pill shown at the trailing edge of a bug column header.
class BugColumnCountBadge extends StatelessWidget {
  const BugColumnCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.xl),
        border: context.cardBorder,
      ),
      child: Text(
        '$count',
        style: context.typography.monoSm.copyWith(color: c.textTertiary),
      ),
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
        width: 258,
        child: Transform.rotate(angle: -0.01, child: child),
      ),
    );
  }
}
