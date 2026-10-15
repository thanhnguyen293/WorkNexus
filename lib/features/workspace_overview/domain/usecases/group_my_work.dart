import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';

/// One status section of a "my work" list.
typedef MyWorkGroup = ({UnifiedStatus status, List<Ticket> tickets});

/// Splits a "my work" list into status sections, ordered by what needs the
/// assignee first: work in progress, then what is still to start, then what
/// is waiting on someone else, then finished. Inside a section the most
/// urgent comes first, then the newest.
class GroupMyWork {
  const GroupMyWork();

  static const _order = [
    UnifiedStatus.inprogress,
    UnifiedStatus.todo,
    UnifiedStatus.inbox,
    UnifiedStatus.blocked,
    UnifiedStatus.review,
    UnifiedStatus.done,
  ];

  List<MyWorkGroup> call(Iterable<Ticket> tickets) {
    final byStatus = <UnifiedStatus, List<Ticket>>{};
    for (final t in tickets) {
      (byStatus[t.status] ??= []).add(t);
    }
    return [
      for (final status in _order)
        if (byStatus[status] case final list?)
          (status: status, tickets: list..sort(_byUrgency)),
    ];
  }

  static int _byUrgency(Ticket a, Ticket b) {
    final byPriority = a.priority.level.compareTo(b.priority.level);
    if (byPriority != 0) return byPriority;
    return _id(b).compareTo(_id(a));
  }

  static int _id(Ticket t) => int.tryParse(t.externalKey) ?? 0;
}
