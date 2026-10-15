import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../board_providers.dart';
import 'board_column_frame.dart';
import 'board_horizontal_scroll.dart';
import 'paged_column_footer.dart';
import 'ticket_card.dart';
import 'zentao_task_column_parts.dart';

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

/// One status column; its end loads the next page of the column's status view
/// while the view has more.
class _TaskColumn extends ConsumerWidget {
  const _TaskColumn({required this.column});

  final ZenTaoTaskBoardColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final more = ref.watch(
      zentaoTaskColumnStreamProvider(column.column).select((s) => s.hasMore),
    );
    final (label, color) = taskColumnVisual(context, column.column);
    return BoardColumnFrame(
      dot: BoardColumnDot(color),
      label: label,
      badge: PagedColumnCount(column.count, more: more),
      itemCount: column.tickets.length + (more ? 1 : 0),
      itemBuilder: (context, i) => i == column.tickets.length
          ? ZenTaoTaskColumnFooter(
              column: column.column,
              visible: column.tickets.length,
            )
          : TicketCard(column.tickets[i], key: ValueKey(column.tickets[i].id)),
    );
  }
}
