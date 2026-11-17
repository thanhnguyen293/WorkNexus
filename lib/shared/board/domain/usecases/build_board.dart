import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/board_model.dart';
import 'compare_tickets.dart';
import 'filter_tickets.dart';

/// Filters tickets then groups them into the six status columns (board order),
/// ordering each column by the query's sort (urgent first by default).
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
      final tickets = byStatus[s]!..sort(boardComparator(q.sort));
      columns.add(BoardColumn(status: s, tickets: tickets));
    }
    return BoardModel(columns: columns);
  }
}
