import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import 'is_assigned_to_me.dart';

/// Whether [Ticket] concerns [Account]'s own user: assigned to them
/// ([IsAssignedToMe]), or — for a ZenTao bug or task — opened by them, or
/// resolved (a bug) or finished (a task) by them. Matched on login handles, as
/// [IsAssignedToMe] matches the assignee.
class IsRelatedToMe {
  const IsRelatedToMe();

  bool call(Ticket ticket, Account account) {
    if (const IsAssignedToMe()(ticket, account)) return true;
    final handles = switch (ticket.providerEntity) {
      ZenTaoBugEntity(:final openedByHandle, :final resolvedByHandle) => [
        openedByHandle,
        resolvedByHandle,
      ],
      ZenTaoTaskEntity(:final openedByHandle, :final finishedByHandle) => [
        openedByHandle,
        finishedByHandle,
      ],
      _ => const <String?>[],
    };
    return handles.any((h) => IsAssignedToMe.isHandleOf(h, account));
  }
}
