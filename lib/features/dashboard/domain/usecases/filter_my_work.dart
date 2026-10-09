import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../value_objects/dashboard_item_kind.dart';

/// The stored tickets of one kind assigned to the account's own user — the
/// full list behind the dashboard — newest (highest id) first. With
/// [openOnly], finished ones are left out.
///
/// The ticket store also holds tickets synced by product and sprint boards,
/// so membership is decided by the assignee, not by how a ticket got there.
class FilterMyWork {
  const FilterMyWork();

  /// ZenTao statuses after which the assignee has nothing left to do. A
  /// `done` task only awaits closing and a `resolved` bug only awaits
  /// verification, but both unify to "review", so the raw status decides.
  static const _finished = {'done', 'closed', 'cancel', 'resolved'};

  /// Whether [t] still needs work from its assignee.
  static bool isOpen(Ticket t) =>
      t.status != UnifiedStatus.done &&
      !_finished.contains(t.providerStatus.trim().toLowerCase());

  List<Ticket> call(
    Iterable<Ticket> tickets, {
    required String accountId,
    required String userAccount,
    required DashboardItemKind kind,
    bool openOnly = false,
  }) {
    final me = userAccount.trim().toLowerCase();
    final mine = tickets
        .where(
          (t) =>
              t.accountId == accountId &&
              t.externalType?.toLowerCase() == kind.name &&
              t.assignee?.trim().toLowerCase() == me &&
              (!openOnly || isOpen(t)),
        )
        .toList();
    mine.sort((a, b) => _id(b).compareTo(_id(a)));
    return mine;
  }

  static int _id(Ticket t) => int.tryParse(t.externalKey) ?? 0;
}
