import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared/board/domain/usecases/filter_tickets.dart';

class ZenTaoBugBoardColumn {
  const ZenTaoBugBoardColumn({required this.column, required this.tickets});

  final ZenTaoBugColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class ZenTaoBugBoardModel {
  const ZenTaoBugBoardModel({required this.columns});

  final List<ZenTaoBugBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  ZenTaoBugBoardColumn column(ZenTaoBugColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

class BuildZenTaoBugBoard extends UseCase<ZenTaoBugBoardModel, BoardQuery> {
  const BuildZenTaoBugBoard({
    this.filter = const FilterTickets(),
    this.includeClosed = true,
  });

  final FilterTickets filter;

  /// Whether the board has a Closed column (the All tab) — without it (the
  /// Unclosed tab) closed bugs are left off the board.
  final bool includeClosed;

  @override
  ZenTaoBugBoardModel call(BoardQuery q) {
    final byColumn = <ZenTaoBugColumn, List<Ticket>>{
      for (final column in ZenTaoBugColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isZenTaoBug(ticket)) continue;
      byColumn[zentaoBugColumnFor(ticket)]!.add(ticket);
    }
    return ZenTaoBugBoardModel(
      columns: [
        for (final column in ZenTaoBugColumn.columns)
          if (includeClosed || column != ZenTaoBugColumn.closed)
            ZenTaoBugBoardColumn(
              column: column,
              tickets: byColumn[column]!..sort(_byPriorityThenUpdated),
            ),
      ],
    );
  }
}

bool _isZenTaoBug(Ticket ticket) =>
    ticket.providerType == ProviderType.zentao &&
    (ticket.externalType ?? '').toLowerCase() == 'bug';

int _byPriorityThenUpdated(Ticket a, Ticket b) {
  final p = a.priority.level.compareTo(b.priority.level);
  if (p != 0) return p;
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bu.compareTo(au);
}
