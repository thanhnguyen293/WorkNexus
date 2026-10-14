import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import '../board_providers.dart';
import '../zentao_table_providers.dart';
import 'ticket_table.dart';
import 'ticket_table_cells.dart';
import 'ticket_table_column.dart';
import 'zentao_bug_column_footer.dart';
import 'zentao_bug_column_parts.dart';

// Column widths; the title takes what is left.
const _wId = 72.0;
const _wSeverity = 108.0;
const _wPriority = 80.0;
const _wStatus = 150.0;
const _wAssignee = 180.0;
const _wResolution = 120.0;
const _wUpdated = 132.0;

/// The ZenTao bug board as a table (see [zentaoBugTableProvider]); its end
/// loads more of the bug view the table has reached.
class ZenTaoBugTableView extends ConsumerWidget {
  const ZenTaoBugTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final table = ref.watch(zentaoBugTableProvider);
    final pending = table.pending;
    final mine = ref.watch(zentaoBugMineProvider);
    return TicketTable(
      id: 'zentao-bug',
      rows: table.rows,
      sort: ref.watch(zentaoBugTableSortProvider),
      onSort: ref.read(zentaoBugTableSortProvider.notifier).sortBy,
      // The footer pages a view through any column drawing on it.
      footer: pending == null
          ? null
          : ZenTaoBugColumnFooter(
              column: ZenTaoBugColumn.values.firstWhere(
                (c) => ZenTaoBugStream.of(c, mine: mine) == pending,
              ),
            ),
      columns: [
        TicketTableColumn(
          id: 'id',
          label: l.tableColumnId,
          sortField: TicketSortField.id,
          width: _wId,
          cell: TableIdCell.new,
        ),
        TicketTableColumn(
          id: 'title',
          label: l.tableColumnTitle,
          sortField: TicketSortField.title,
          cell: TableTitleCell.new,
        ),
        TicketTableColumn(
          id: 'severity',
          label: l.severity,
          sortField: TicketSortField.severity,
          width: _wSeverity,
          cell: TableSeverityCell.new,
        ),
        TicketTableColumn(
          id: 'priority',
          label: l.priority,
          sortField: TicketSortField.priority,
          width: _wPriority,
          cell: TablePriorityCell.new,
        ),
        TicketTableColumn(
          id: 'status',
          label: l.status,
          sortField: TicketSortField.status,
          width: _wStatus,
          cell: (t) => _StatusCell(t),
        ),
        TicketTableColumn(
          id: 'assignee',
          label: l.assignedTo,
          sortField: TicketSortField.assignee,
          width: _wAssignee,
          cell: TableAssigneeCell.new,
        ),
        TicketTableColumn(
          id: 'resolution',
          label: l.resolution,
          sortField: TicketSortField.resolution,
          width: _wResolution,
          cell: (t) => TableTextCell(_resolution(t)),
        ),
        TicketTableColumn(
          id: 'updated',
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

/// How the bug was resolved, as ZenTao names it; nothing while unresolved.
String _resolution(Ticket t) => switch (t.providerEntity) {
  ZenTaoBugEntity(:final resolution?) when resolution.isNotEmpty =>
    zentaoBugResolutionLabels[resolution] ?? resolution,
  _ => '',
};

class _StatusCell extends StatelessWidget {
  const _StatusCell(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final (label, color) = bugColumnVisual(context, zentaoBugColumnFor(ticket));
    return TableStatusCell(label, color);
  }
}
