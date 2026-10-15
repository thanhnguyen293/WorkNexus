import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared/board/domain/usecases/filter_tickets.dart';

import '../usecases/is_due_this_week.dart';

class ZenTaoTaskBoardColumn {
  const ZenTaoTaskBoardColumn({required this.column, required this.tickets});

  final ZenTaoTaskColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class ZenTaoTaskBoardModel {
  const ZenTaoTaskBoardModel({required this.columns});

  final List<ZenTaoTaskBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  ZenTaoTaskBoardColumn column(ZenTaoTaskColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

class BuildZenTaoTaskBoard extends UseCase<ZenTaoTaskBoardModel, BoardQuery> {
  const BuildZenTaoTaskBoard({
    this.filter = const FilterTickets(),
    this.isDueThisWeek = const IsDueThisWeek(),
    this.dueThisWeekOnly = false,
  });

  final FilterTickets filter;
  final IsDueThisWeek isDueThisWeek;
  final bool dueThisWeekOnly;

  @override
  ZenTaoTaskBoardModel call(BoardQuery q) {
    final byColumn = <ZenTaoTaskColumn, List<Ticket>>{
      for (final column in ZenTaoTaskColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isZenTaoTask(ticket)) continue;
      if (dueThisWeekOnly) {
        final deadline = extractZenTaoDeadline(ticket);
        if (deadline == null || !isDueThisWeek(deadline, now: q.now)) continue;
      }
      byColumn[zentaoTaskColumnFor(ticket)]!.add(ticket);
    }
    return ZenTaoTaskBoardModel(
      columns: [
        for (final column in ZenTaoTaskColumn.columns)
          ZenTaoTaskBoardColumn(
            column: column,
            tickets: byColumn[column]!..sort(_byPriorityThenUpdated),
          ),
      ],
    );
  }
}

bool _isZenTaoTask(Ticket ticket) =>
    ticket.providerType == ProviderType.zentao &&
    (ticket.externalType ?? '').toLowerCase() == 'task';

int _byPriorityThenUpdated(Ticket a, Ticket b) {
  final p = a.priority.level.compareTo(b.priority.level);
  if (p != 0) return p;
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bu.compareTo(au);
}
