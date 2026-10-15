import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../board_providers.dart';
import 'board_column_frame.dart';
import 'non_fix_resolution_dialog.dart';
import 'paged_column_footer.dart';
import 'ticket_card.dart';
import 'zentao_bug_column_footer.dart';
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
    final col = widget.column;
    final more = ref.watch(
      zentaoBugColumnStreamProvider(col.column).select((s) => s.hasMore),
    );
    final (label, color) = bugColumnVisual(context, col.column);
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
      builder: (context, _, _) => BoardColumnFrame(
        highlighted: _over,
        dot: BoardColumnDot(color),
        label: label,
        badge: PagedColumnCount(col.count, more: more),
        itemCount: col.tickets.length + (more ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == col.tickets.length) {
            return ZenTaoBugColumnFooter(column: col.column);
          }
          final ticket = col.tickets[i];
          return Draggable<Ticket>(
            key: ValueKey(ticket.id),
            data: ticket,
            feedback: BugCardDragFeedback(child: TicketCard(ticket)),
            childWhenDragging: Opacity(opacity: 0.4, child: TicketCard(ticket)),
            child: TicketCard(ticket),
          );
        },
      ),
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

    final l = AppL10n.of(context);
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
    // Dropped into Resolved / Verify: the bug is fixed.
    if (result.isOk && target == ZenTaoBugColumn.resolvedVerify) {
      ref.read(celebrationProvider.notifier).celebrate();
    }
    final label = zentaoBugResolutionLabels[resolution] ?? resolution;
    showAppSnack(context, switch (result) {
      Ok() => l.boardBugResolvedAs(label),
      Err(:final failure) => l.boardBugResolveFailed(failure.message),
    }, isError: !result.isOk);
  }

  Future<void> _activate(Ticket ticket) async {
    final l = AppL10n.of(context);
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
    showAppSnack(context, switch (result) {
      Ok() => l.boardBugActivated,
      Err(:final failure) => l.boardBugActivateFailed(failure.message),
    }, isError: !result.isOk);
  }

  Future<void> _confirm(Ticket ticket) async {
    final l = AppL10n.of(context);
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
    showAppSnack(context, switch (result) {
      Ok() => l.boardBugConfirmed,
      Err(:final failure) => l.boardBugConfirmFailed(failure.message),
    }, isError: !result.isOk);
  }
}
