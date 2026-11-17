import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';

/// The order a Kanban board starts in: most urgent first, then most recently
/// updated.
const boardDefaultSort = TicketSort(TicketSortField.priority);

/// What a Kanban board offers to sort its cards by. Status is left out: the
/// columns already are the status.
const boardSortFields = [
  TicketSortField.priority,
  TicketSortField.updated,
  TicketSortField.id,
  TicketSortField.title,
  TicketSortField.assignee,
];

/// [boardSortFields] plus severity, for boards whose tickets carry one (bugs).
const boardSortFieldsWithSeverity = [
  TicketSortField.priority,
  TicketSortField.severity,
  TicketSortField.updated,
  TicketSortField.id,
  TicketSortField.title,
  TicketSortField.assignee,
];

/// Orders tickets by [sort]'s field, falling back to [tieBreak] among equals.
/// Missing values sort first ascending (last descending), as ZenTao's empty
/// fields do.
int Function(Ticket, Ticket) ticketComparator(
  TicketSort sort, {
  int Function(Ticket, Ticket) tieBreak = compareByIdDesc,
}) {
  final key = _keys[sort.field]!;
  return (a, b) {
    final c = _compareKeys(key(a), key(b));
    if (c != 0) return sort.descending ? -c : c;
    return tieBreak(a, b);
  };
}

/// A board column's order: [sort], then most recently updated, then newest.
int Function(Ticket, Ticket) boardComparator(TicketSort sort) =>
    ticketComparator(sort, tieBreak: _byUpdatedThenId);

int _byUpdatedThenId(Ticket a, Ticket b) {
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final c = bu.compareTo(au);
  return c != 0 ? c : compareByIdDesc(a, b);
}

/// Higher ids first; a non-numeric key falls back to text order.
int compareByIdDesc(Ticket a, Ticket b) {
  final ai = int.tryParse(a.externalKey);
  final bi = int.tryParse(b.externalKey);
  if (ai != null && bi != null) return bi.compareTo(ai);
  return b.externalKey.compareTo(a.externalKey);
}

final Map<TicketSortField, Comparable<Object>? Function(Ticket)> _keys = {
  TicketSortField.id: (t) => int.tryParse(t.externalKey),
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

int _compareKeys(Comparable<Object>? a, Comparable<Object>? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : -1) : 1;
  return a.compareTo(b);
}
