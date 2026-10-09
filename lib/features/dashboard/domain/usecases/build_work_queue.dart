import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';

/// The user's open work, split the way they act on it: what is already in
/// progress, then what has not been started.
typedef WorkQueue = ({List<Ticket> inProgress, List<Ticket> notStarted});

/// Merges open bugs and tasks into one queue. Each group is ordered by
/// priority (most urgent first), then newest first, so the next thing to
/// pick up is on top whatever its kind.
class BuildWorkQueue {
  const BuildWorkQueue();

  WorkQueue call(Iterable<Ticket> openTickets) {
    final sorted = openTickets.toList()
      ..sort((a, b) {
        final byPriority = a.priority.level.compareTo(b.priority.level);
        if (byPriority != 0) return byPriority;
        return _id(b).compareTo(_id(a));
      });
    return (
      inProgress: [
        for (final t in sorted)
          if (t.status == UnifiedStatus.inprogress) t,
      ],
      notStarted: [
        for (final t in sorted)
          if (t.status != UnifiedStatus.inprogress) t,
      ],
    );
  }

  static int _id(Ticket t) => int.tryParse(t.externalKey) ?? 0;
}
