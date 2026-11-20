import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';

/// A person's open synced tickets: those assigned to them, and those they
/// reported that someone else now holds.
typedef PersonTickets = ({List<Ticket> assigned, List<Ticket> reported});

/// Picks the open tickets of ZenTao user [handle] on account [accountId] from
/// the synced [tickets], most recently updated first. Handles compare without
/// case: ZenTao logins are case-insensitive.
class ListPersonTickets {
  const ListPersonTickets();

  PersonTickets call(
    List<Ticket> tickets, {
    required String accountId,
    required String handle,
  }) {
    final who = handle.trim().toLowerCase();
    final assigned = <Ticket>[];
    final reported = <Ticket>[];
    if (who.isEmpty) return (assigned: assigned, reported: reported);
    for (final t in tickets) {
      if (t.accountId != accountId || t.status == UnifiedStatus.done) continue;
      if (t.assignee?.toLowerCase() == who) {
        assigned.add(t);
      } else if (_openedBy(t)?.toLowerCase() == who) {
        reported.add(t);
      }
    }
    int newestFirst(Ticket a, Ticket b) =>
        (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(
          a.updatedAt ?? a.createdAt ?? DateTime(0),
        );
    assigned.sort(newestFirst);
    reported.sort(newestFirst);
    return (assigned: assigned, reported: reported);
  }

  static String? _openedBy(Ticket t) => switch (t.providerEntity) {
    ZenTaoBugEntity(:final openedByHandle) => openedByHandle,
    ZenTaoTaskEntity(:final openedByHandle) => openedByHandle,
    _ => null,
  };
}
