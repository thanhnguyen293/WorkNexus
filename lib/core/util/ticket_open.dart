import '../domain/entities/ticket.dart';
import '../domain/value_objects/unified_status.dart';

/// ZenTao statuses after which the assignee has nothing left to do. A `done`
/// task only awaits closing and a `resolved` bug only awaits verification,
/// but both unify to "review", so the raw status decides.
const _finished = {'done', 'closed', 'cancel', 'resolved'};

/// Whether [t] still needs work from its assignee.
bool isOpenForAssignee(Ticket t) =>
    t.status != UnifiedStatus.done &&
    !_finished.contains(t.providerStatus.trim().toLowerCase());
