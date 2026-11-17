import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/usecase/usecase.dart';
import 'compare_tickets.dart';

/// One stretch of a paged table: the (filtered) tickets that belong to server
/// view [view], and whether every page of that view is loaded.
class PagedTableSegment<V> {
  const PagedTableSegment({
    required this.view,
    required this.tickets,
    required this.complete,
  });

  final V view;
  final List<Ticket> tickets;
  final bool complete;
}

/// The views to lay out, in status order, and the order the table asks for.
class PagedTableQuery<V> {
  const PagedTableQuery({
    required this.segments,
    this.sort = TicketSort.newest,
  });

  final List<PagedTableSegment<V>> segments;
  final TicketSort sort;
}

/// A paged table's rows so far, and the view whose next page continues it.
class PagedTable<V> {
  const PagedTable({required this.rows, this.pending});

  final List<Ticket> rows;

  /// The view to load more of at the table's end; null once all are loaded.
  final V? pending;
}

/// Lays a board's paged views out as one flat table, as ZenTao lists them:
/// view by view in status order (reversed when sorting by status descending),
/// and within each view in the [TicketSort] its pages were fetched in. Rows of
/// a view only show once every view before it is fully loaded, so loading more
/// only ever adds rows at the table's end.
class BuildPagedTable<V> extends UseCase<PagedTable<V>, PagedTableQuery<V>> {
  const BuildPagedTable();

  @override
  PagedTable<V> call(PagedTableQuery<V> q) {
    final sort = q.sort;
    final byStatus = sort.field == TicketSortField.status;
    final segments = byStatus && sort.descending
        ? q.segments.reversed
        : q.segments;
    final compare = byStatus ? compareByIdDesc : ticketComparator(sort);
    final rows = <Ticket>[];
    for (final segment in segments) {
      rows.addAll([...segment.tickets]..sort(compare));
      if (!segment.complete) {
        return PagedTable(rows: rows, pending: segment.view);
      }
    }
    return PagedTable(rows: rows);
  }
}
