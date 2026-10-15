import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/board_model.dart';
import 'filter_tickets.dart';

/// Filters tickets then groups them into the six status columns (board order),
/// sorting each column by priority (urgent first) then most-recently-updated.
class BuildBoard extends UseCase<BoardModel, BoardQuery> {
  const BuildBoard({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  BoardModel call(BoardQuery q) {
    final filtered = filter(q);
    final byStatus = <UnifiedStatus, List<Ticket>>{
      for (final s in UnifiedStatus.columns) s: <Ticket>[],
    };
    for (final t in filtered) {
      byStatus[t.status]!.add(t);
    }
    final columns = <BoardColumn>[];
    for (final s in UnifiedStatus.columns) {
      final tickets = byStatus[s]!..sort(_byPriorityThenUpdated);
      columns.add(BoardColumn(status: s, tickets: tickets));
    }
    return BoardModel(columns: columns);
  }
}

int _byPriorityThenUpdated(Ticket a, Ticket b) {
  final p = a.priority.level.compareTo(b.priority.level);
  if (p != 0) return p;
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bu.compareTo(au); // most recent first
}
