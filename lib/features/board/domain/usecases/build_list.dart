import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';
import 'filter_tickets.dart';

/// Filters tickets then sorts them for the dense List view:
/// workspace order → status order → priority → most-recently-updated.
class BuildList extends UseCase<List<Ticket>, BoardQuery> {
  const BuildList({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  List<Ticket> call(BoardQuery q) {
    final filtered = filter(q);
    int wsRank(Ticket t) {
      final ws = q.accountWorkspace[t.accountId];
      final idx = q.workspaceOrder.indexOf(ws ?? '');
      return idx < 0 ? 1 << 20 : idx;
    }

    filtered.sort((a, b) {
      final w = wsRank(a).compareTo(wsRank(b));
      if (w != 0) return w;
      final s = a.status.order.compareTo(b.status.order);
      if (s != 0) return s;
      final p = a.priority.level.compareTo(b.priority.level);
      if (p != 0) return p;
      final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bu.compareTo(au);
    });
    return filtered;
  }
}
