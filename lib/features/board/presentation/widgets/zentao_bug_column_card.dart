import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/sync_service.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../board_providers.dart';
import 'non_fix_resolution_dialog.dart';
import 'ticket_card.dart';
import 'zentao_bug_column_parts.dart';

/// One draggable status column on the ZenTao bug board. Dropping a card here
/// runs the matching bug transition (confirm / activate / resolve).
class ZenTaoBugColumnCard extends ConsumerStatefulWidget {
  const ZenTaoBugColumnCard({super.key, required this.column});

  final ZenTaoBugBoardColumn column;

  @override
  ConsumerState<ZenTaoBugColumnCard> createState() =>
      _ZenTaoBugColumnCardState();
}

class _ZenTaoBugColumnCardState extends ConsumerState<ZenTaoBugColumnCard> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = widget.column;
    return DragTarget<Ticket>(
      onWillAcceptWithDetails: (details) {
        final accepted = _canDrop(details.data, col.column);
        if (accepted) setState(() => _over = true);
        return accepted;
      },
      onLeave: (_) => setState(() => _over = false),
      onAcceptWithDetails: (details) async {
        setState(() => _over = false);
        await _handleDrop(details.data, col.column);
      },
      builder: (context, _, _) {
        return Container(
          width: 272,
          decoration: BoxDecoration(
            color: _over ? c.selectionFill : c.surface,
            borderRadius: BorderRadius.circular(context.radii.lg),
            border: context.cardBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.xl,
                  context.spacing.xl,
                  context.spacing.xl,
                  context.spacing.md,
                ),
                child: Row(
                  children: [
                    BugColumnDot(col.column),
                    SizedBox(width: context.spacing.md),
                    Expanded(
                      child: Text(
                        _columnLabel(col.column),
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.bodySmStrong.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    BugColumnCountBadge(col.count),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.sm,
                    context.spacing.xxs,
                    context.spacing.sm,
                    context.spacing.md,
                  ),
                  itemCount: col.tickets.length,
                  itemBuilder: (context, i) {
                    final ticket = col.tickets[i];
                    return Draggable<Ticket>(
                      data: ticket,
                      feedback: BugCardDragFeedback(child: TicketCard(ticket)),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: TicketCard(ticket),
                      ),
                      child: TicketCard(ticket),
                    );
                  },
                  separatorBuilder: (_, _) =>
                      SizedBox(height: context.spacing.md),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canDrop(Ticket ticket, ZenTaoBugColumn target) {
    final current = zentaoBugColumnFor(ticket);
    if (current == target) return false;
    return switch (target) {
      // ZenTao has no "un-confirm": nothing can move back into New/Unconfirmed.
      ZenTaoBugColumn.newUnconfirmed => false,
      // Reachable two ways: confirming a New/Unconfirmed bug (confirmed = 1), or
      // reopening a resolved/closed bug (activate) — a reopened bug is active
      // AND still confirmed. Either way it lands active in Confirmed/To Fix.
      ZenTaoBugColumn.confirmedToFix =>
        current == ZenTaoBugColumn.newUnconfirmed ||
            current == ZenTaoBugColumn.resolvedVerify ||
            current == ZenTaoBugColumn.postponed ||
            current == ZenTaoBugColumn.nonFix ||
            current == ZenTaoBugColumn.closed,
      // Resolving is allowed from any non-resolved state.
      ZenTaoBugColumn.resolvedVerify ||
      ZenTaoBugColumn.postponed ||
      ZenTaoBugColumn.nonFix => true,
      ZenTaoBugColumn.closed => false,
    };
  }

  Future<void> _handleDrop(Ticket ticket, ZenTaoBugColumn target) async {
    if (target == ZenTaoBugColumn.confirmedToFix) {
      // A New/Unconfirmed bug is confirmed (confirmed = 1); a resolved/closed
      // one is reopened (activate). Both land active in Confirmed/To Fix.
      if (zentaoBugColumnFor(ticket) == ZenTaoBugColumn.newUnconfirmed) {
        await _confirm(ticket);
      } else {
        await _activate(ticket);
      }
      return;
    }

    final resolution = switch (target) {
      ZenTaoBugColumn.resolvedVerify => 'fixed',
      ZenTaoBugColumn.postponed => 'postponed',
      ZenTaoBugColumn.nonFix => await showDialog<String>(
        context: context,
        builder: (_) => const NonFixResolutionDialog(),
      ),
      ZenTaoBugColumn.newUnconfirmed ||
      ZenTaoBugColumn.confirmedToFix ||
      ZenTaoBugColumn.closed => null,
    };
    if (resolution == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    ref.read(ticketActionPendingProvider.notifier).start(ticket.id);
    final Result<void> result;
    try {
      result = await getIt<SyncService>().resolveBug(
        ticket,
        resolution: resolution,
        build: 'trunk',
      );
    } finally {
      ref.read(ticketActionPendingProvider.notifier).finish(ticket.id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(_snackMessage(result, resolution))),
    );
  }

  Future<void> _activate(Ticket ticket) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(ticketActionPendingProvider.notifier).start(ticket.id);
    final Result<void> result;
    try {
      // A reopened bug is active + confirmed → it lands in Confirmed/To Fix
      // (activateBug's default optimistic status).
      result = await getIt<SyncService>().activateBug(ticket, build: 'trunk');
    } finally {
      ref.read(ticketActionPendingProvider.notifier).finish(ticket.id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(_activateSnackMessage(result))),
    );
  }

  Future<void> _confirm(Ticket ticket) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(ticketActionPendingProvider.notifier).start(ticket.id);
    final Result<void> result;
    try {
      // Confirming keeps the bug active + assigned to me → it lands in
      // Confirmed/To Fix (confirmBug's optimistic status).
      result = await getIt<SyncService>().confirmBug(ticket);
    } finally {
      ref.read(ticketActionPendingProvider.notifier).finish(ticket.id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(_confirmSnackMessage(result))),
    );
  }
}

String _snackMessage(Result<void> result, String resolution) {
  final label = zentaoBugResolutionLabels[resolution] ?? resolution;
  if (result.isOk) return 'Resolved as $label';
  return 'Resolve failed: ${result.failureOrNull?.message ?? 'error'}';
}

String _activateSnackMessage(Result<void> result) {
  if (result.isOk) return 'Activated bug';
  return 'Activate failed: ${result.failureOrNull?.message ?? 'error'}';
}

String _confirmSnackMessage(Result<void> result) {
  if (result.isOk) return 'Confirmed bug';
  return 'Confirm failed: ${result.failureOrNull?.message ?? 'error'}';
}

String _columnLabel(ZenTaoBugColumn column) => switch (column) {
  ZenTaoBugColumn.newUnconfirmed => 'New / Unconfirmed',
  ZenTaoBugColumn.confirmedToFix => 'Confirmed / To Fix',
  ZenTaoBugColumn.resolvedVerify => 'Resolved / Verify',
  ZenTaoBugColumn.postponed => 'Postponed',
  ZenTaoBugColumn.nonFix => 'Non-Fix',
  ZenTaoBugColumn.closed => 'Closed',
};
