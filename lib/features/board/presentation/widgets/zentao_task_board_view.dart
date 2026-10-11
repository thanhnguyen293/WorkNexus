import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../../domain/value_objects/zentao_task_column.dart';
import '../board_providers.dart';
import 'board_column_frame.dart';
import 'board_horizontal_scroll.dart';
import 'ticket_card.dart';

class ZenTaoTaskBoardView extends ConsumerWidget {
  const ZenTaoTaskBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(zentaoTaskBoardProvider);
    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in board.columns) ...[
            _TaskColumn(column: col),
            SizedBox(width: context.spacing.xl),
          ],
        ],
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
    final l = AppL10n.of(context);
    final (label, color) = switch (column.column) {
      ZenTaoTaskColumn.notStarted => (l.boardTaskColNotStarted, c.textTertiary),
      ZenTaoTaskColumn.inProgress => (l.boardTaskColInProgress, c.accent),
      ZenTaoTaskColumn.paused => (l.boardTaskColPaused, c.warning),
      ZenTaoTaskColumn.doneVerify => (l.boardTaskColDoneVerify, c.success),
      ZenTaoTaskColumn.closed => (l.boardTaskColClosed, c.textSecondary),
      ZenTaoTaskColumn.canceled => (l.boardTaskColCanceled, c.error),
    };
    return BoardColumnFrame(
      dot: BoardColumnDot(color),
      label: label,
      badge: AppCountBadge(column.count),
      itemCount: column.tickets.length,
      itemBuilder: (context, i) => TicketCard(column.tickets[i]),
    );
  }
}
