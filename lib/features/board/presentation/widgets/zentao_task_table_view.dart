import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/util/hours_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../board_providers.dart';
import '../zentao_table_providers.dart';
import 'ticket_table.dart';
import 'ticket_table_cells.dart';
import 'zentao_task_column_parts.dart';

// Column widths; the title takes what is left.
const _wId = 72.0;
const _wPriority = 80.0;
const _wStatus = 140.0;
const _wAssignee = 180.0;
const _wHours = 72.0;
const _wUpdated = 132.0;

/// The ZenTao task board as a table (see [zentaoTaskTableProvider]); its end
/// loads more of the status view the table has reached.
class ZenTaoTaskTableView extends ConsumerWidget {
  const ZenTaoTaskTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final table = ref.watch(zentaoTaskTableProvider);
    final pending = table.pending;
    return TicketTable(
      rows: table.rows,
      sort: ref.watch(zentaoTaskTableSortProvider),
      onSort: ref.read(zentaoTaskTableSortProvider.notifier).sortBy,
      footer: pending == null
          ? null
          : ZenTaoTaskColumnFooter(
              column: pending,
              visible: table.rows
                  .where((t) => zentaoTaskColumnFor(t) == pending)
                  .length,
            ),
      columns: [
        TicketTableColumn(
          label: l.tableColumnId,
          sortField: TicketSortField.id,
          width: _wId,
          cell: TableIdCell.new,
        ),
        TicketTableColumn(
          label: l.tableColumnTitle,
          sortField: TicketSortField.title,
          cell: TableTitleCell.new,
        ),
        TicketTableColumn(
          label: l.priority,
          sortField: TicketSortField.priority,
          width: _wPriority,
          cell: TablePriorityCell.new,
        ),
        TicketTableColumn(
          label: l.status,
          sortField: TicketSortField.status,
          width: _wStatus,
          cell: (t) => _StatusCell(t),
        ),
        TicketTableColumn(
          label: l.assignedTo,
          sortField: TicketSortField.assignee,
          width: _wAssignee,
          cell: TableAssigneeCell.new,
        ),
        TicketTableColumn(
          label: l.estimate,
          sortField: TicketSortField.estimate,
          width: _wHours,
          alignEnd: true,
          cell: (t) => _HoursCell(t, (task) => task.estimate),
        ),
        TicketTableColumn(
          label: l.tableColumnLeft,
          sortField: TicketSortField.left,
          width: _wHours,
          alignEnd: true,
          cell: (t) => _HoursCell(t, (task) => task.left),
        ),
        TicketTableColumn(
          label: l.updated,
          sortField: TicketSortField.updated,
          width: _wUpdated,
          alignEnd: true,
          cell: TableUpdatedCell.new,
        ),
      ],
    );
  }
}

/// One of a task's effort figures in hours (`7.5 h`), or nothing.
class _HoursCell extends StatelessWidget {
  const _HoursCell(this.ticket, this.pick);

  final Ticket ticket;
  final double? Function(ZenTaoTaskEntity task) pick;

  @override
  Widget build(BuildContext context) {
    final hours = switch (ticket.providerEntity) {
      final ZenTaoTaskEntity task => pick(task),
      _ => null,
    };
    return TableTextCell(
      hours == null ? '' : AppL10n.of(context).tableHours(hoursText(hours)),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final (label, color) = taskColumnVisual(
      context,
      zentaoTaskColumnFor(ticket),
    );
    return TableStatusCell(label, color);
  }
}
