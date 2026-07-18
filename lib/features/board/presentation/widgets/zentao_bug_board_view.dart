import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
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

class ZenTaoBugBoardView extends ConsumerWidget {
  const ZenTaoBugBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(zentaoBugBoardProvider);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final col in board.columns) ...[
              _BugColumn(column: col),
              SizedBox(width: context.spacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}

class _BugColumn extends ConsumerStatefulWidget {
  const _BugColumn({required this.column});

  final ZenTaoBugBoardColumn column;

  @override
  ConsumerState<_BugColumn> createState() => _BugColumnState();
}

class _BugColumnState extends ConsumerState<_BugColumn> {
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
                    _ColumnDot(col.column),
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
                    _CountBadge(col.count),
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
                      feedback: _DragFeedback(child: TicketCard(ticket)),
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
    if (zentaoBugColumnFor(ticket) == target) return false;
    return switch (target) {
      ZenTaoBugColumn.newUnconfirmed ||
      ZenTaoBugColumn.confirmedToFix ||
      ZenTaoBugColumn.resolvedVerify ||
      ZenTaoBugColumn.postponed ||
      ZenTaoBugColumn.nonFix => true,
      ZenTaoBugColumn.closed => false,
    };
  }

  Future<void> _handleDrop(Ticket ticket, ZenTaoBugColumn target) async {
    if (target == ZenTaoBugColumn.newUnconfirmed ||
        target == ZenTaoBugColumn.confirmedToFix) {
      await _activate(ticket, target);
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

  Future<void> _activate(Ticket ticket, ZenTaoBugColumn target) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(ticketActionPendingProvider.notifier).start(ticket.id);
    final Result<void> result;
    try {
      result = await getIt<SyncService>().activateBug(
        ticket,
        build: 'trunk',
        optimisticStatus: target == ZenTaoBugColumn.newUnconfirmed
            ? UnifiedStatus.inbox
            : UnifiedStatus.todo,
      );
    } finally {
      ref.read(ticketActionPendingProvider.notifier).finish(ticket.id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(_activateSnackMessage(result))),
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

String _columnLabel(ZenTaoBugColumn column) => switch (column) {
  ZenTaoBugColumn.newUnconfirmed => 'New / Unconfirmed',
  ZenTaoBugColumn.confirmedToFix => 'Confirmed / To Fix',
  ZenTaoBugColumn.resolvedVerify => 'Resolved / Verify',
  ZenTaoBugColumn.postponed => 'Postponed',
  ZenTaoBugColumn.nonFix => 'Non-Fix',
  ZenTaoBugColumn.closed => 'Closed',
};

class _ColumnDot extends StatelessWidget {
  const _ColumnDot(this.column);

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

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

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

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});

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
