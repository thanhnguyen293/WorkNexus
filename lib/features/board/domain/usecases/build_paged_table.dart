import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/usecase/usecase.dart';

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
    final compare = byStatus ? _byId : _comparator(sort);
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

/// Orders tickets by [sort]'s field, newest first among equals.
int Function(Ticket, Ticket) _comparator(TicketSort sort) {
  final key = _keys[sort.field]!;
  return (a, b) {
    final c = _compareKeys(key(a), key(b));
    if (c != 0) return sort.descending ? -c : c;
    return _byId(a, b);
  };
}

final Map<TicketSortField, Comparable<Object>? Function(Ticket)> _keys = {
  TicketSortField.id: (t) => _id(t),
  TicketSortField.title: (t) => t.title.toLowerCase(),
  TicketSortField.priority: (t) => t.priority.level,
  TicketSortField.severity: (t) => t.severity,
  TicketSortField.status: (t) => null,
  TicketSortField.assignee: (t) => t.assignee?.toLowerCase(),
  TicketSortField.estimate: (t) => switch (t.providerEntity) {
    ZenTaoTaskEntity(:final estimate) => estimate,
    _ => null,
  },
  TicketSortField.left: (t) => switch (t.providerEntity) {
    ZenTaoTaskEntity(:final left) => left,
    _ => null,
  },
  TicketSortField.resolution: (t) => switch (t.providerEntity) {
    ZenTaoBugEntity(:final resolution) => resolution,
    _ => null,
  },
  TicketSortField.updated: (t) => t.updatedAt,
};

/// Missing values sort first, as ZenTao's empty fields do ascending.
int _compareKeys(Comparable<Object>? a, Comparable<Object>? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  return a.compareTo(b);
}

/// Higher ZenTao ids first; a non-numeric key falls back to text order.
int _byId(Ticket a, Ticket b) {
  final ai = int.tryParse(a.externalKey);
  final bi = int.tryParse(b.externalKey);
  if (ai != null && bi != null) return bi.compareTo(ai);
  return b.externalKey.compareTo(a.externalKey);
}

int? _id(Ticket t) => int.tryParse(t.externalKey);
