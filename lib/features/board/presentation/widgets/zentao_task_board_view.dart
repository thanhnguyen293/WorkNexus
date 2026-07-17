import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../../domain/value_objects/zentao_task_column.dart';
import '../board_providers.dart';
import 'ticket_card.dart';

class ZenTaoTaskBoardView extends ConsumerWidget {
  const ZenTaoTaskBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(zentaoTaskBoardProvider);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final col in board.columns) ...[
              _TaskColumn(column: col),
              SizedBox(width: context.spacing.xl),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskColumn extends StatelessWidget {
  const _TaskColumn({required this.column});

  final ZenTaoTaskBoardColumn column;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: c.surface,
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
                _ColumnDot(column.column),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Text(
                    _columnLabel(column.column),
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: context.spacing.md),
                _CountBadge(column.count),
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
              itemCount: column.tickets.length,
              itemBuilder: (context, i) => TicketCard(column.tickets[i]),
              separatorBuilder: (_, _) => SizedBox(height: context.spacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

String _columnLabel(ZenTaoTaskColumn column) => switch (column) {
  ZenTaoTaskColumn.notStarted => 'Not Started',
  ZenTaoTaskColumn.inProgress => 'In Progress',
  ZenTaoTaskColumn.paused => 'Paused',
  ZenTaoTaskColumn.doneVerify => 'Done / Verify',
  ZenTaoTaskColumn.closed => 'Closed',
  ZenTaoTaskColumn.canceled => 'Canceled',
};

class _ColumnDot extends StatelessWidget {
  const _ColumnDot(this.column);

  final ZenTaoTaskColumn column;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (column) {
      ZenTaoTaskColumn.notStarted => c.textTertiary,
      ZenTaoTaskColumn.inProgress => c.accent,
      ZenTaoTaskColumn.paused => c.warning,
      ZenTaoTaskColumn.doneVerify => c.success,
      ZenTaoTaskColumn.closed => c.textSecondary,
      ZenTaoTaskColumn.canceled => c.error,
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
