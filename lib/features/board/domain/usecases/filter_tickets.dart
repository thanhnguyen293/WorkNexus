import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/filter_state.dart';
import '../value_objects/saved_view.dart';

/// Everything needed to filter/group tickets, kept as plain data so the logic is
/// pure and unit-testable with no Flutter/IO.
class BoardQuery {
  const BoardQuery({
    required this.tickets,
    required this.filter,
    required this.accountWorkspace,
    required this.now,
    this.workspaceOrder = const [],
  });

  final List<Ticket> tickets;
  final FilterState filter;

  /// accountId → workspaceId, for workspace scoping.
  final Map<String, String> accountWorkspace;

  /// Reference time for the "Today" saved view.
  final DateTime now;

  /// Workspace ids in display order (for the List view sort).
  final List<String> workspaceOrder;
}

/// Whether a ticket satisfies a built-in saved view.
bool savedViewMatches(SavedView view, Ticket t, DateTime now) {
  switch (view) {
    case SavedView.all:
      return true;
    case SavedView.today:
      final u = t.updatedAt;
      return u != null && now.difference(u).inHours.abs() < 24;
    case SavedView.mine:
      return t.status == UnifiedStatus.todo ||
          t.status == UnifiedStatus.inprogress;
    case SavedView.review:
      return t.status == UnifiedStatus.review;
    case SavedView.blocked:
      return t.status == UnifiedStatus.blocked;
  }
}

/// Applies the full [FilterState] (workspace + saved view + chip filters +
/// search) to the ticket list. Order is preserved from the input.
class FilterTickets extends UseCase<List<Ticket>, BoardQuery> {
  const FilterTickets();

  @override
  List<Ticket> call(BoardQuery q) {
    final f = q.filter;
    final query = f.search.trim().toLowerCase();
    return q.tickets.where((t) {
      // Workspace scope.
      if (f.workspaceId != 'all') {
        if (q.accountWorkspace[t.accountId] != f.workspaceId) return false;
      }
      if (!savedViewMatches(f.savedView, t, q.now)) return false;
      if (f.providers.isNotEmpty && !f.providers.contains(t.providerType)) {
        return false;
      }
      if (f.accountIds.isNotEmpty && !f.accountIds.contains(t.accountId)) {
        return false;
      }
      if (f.projectIds.isNotEmpty && !f.projectIds.contains(t.projectId)) {
        return false;
      }
      if (f.statuses.isNotEmpty && !f.statuses.contains(t.status)) return false;
      if (f.priorities.isNotEmpty && !f.priorities.contains(t.priority)) {
        return false;
      }
      if (f.severities.isNotEmpty &&
          !(t.severity != null && f.severities.contains(t.severity))) {
        return false;
      }
      if (f.assignees.isNotEmpty && !f.assignees.contains(t.assignee ?? '')) {
        return false;
      }
      if (f.bugTypes.isNotEmpty || f.resolutions.isNotEmpty) {
        final entity = t.providerEntity;
        final bugType = entity is ZenTaoBugEntity
            ? (entity.bugType ?? '').toLowerCase()
            : '';
        final resolution = entity is ZenTaoBugEntity
            ? (entity.resolution ?? '').toLowerCase()
            : '';
        if (f.bugTypes.isNotEmpty && !f.bugTypes.contains(bugType)) {
          return false;
        }
        if (f.resolutions.isNotEmpty && !f.resolutions.contains(resolution)) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final hay = [
          t.title,
          t.externalKey,
          t.externalType ?? '',
          t.assignee ?? '',
          t.providerType.code,
          t.labels.join(' '),
        ].join(' ').toLowerCase();
        if (!hay.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
