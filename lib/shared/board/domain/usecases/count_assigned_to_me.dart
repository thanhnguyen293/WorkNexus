import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/util/ticket_open.dart';
import '../value_objects/assigned_counts.dart';
import 'is_assigned_to_me.dart';

/// Counts the open tickets assigned to each account's own user for every node
/// of the sources tree (see [AssignedCounts]).
///
/// A ticket is the user's as [IsAssignedToMe] decides.
///
/// [pinnedProjects] holds `accountId:id` keys of pinned ZenTao products and
/// GitLab / GitHub projects; [pinnedExecutions] of pinned ZenTao executions.
/// Tickets under a pin count toward "Pinned" instead of their group.
class CountAssignedToMe {
  const CountAssignedToMe();

  AssignedCounts call({
    required Iterable<Ticket> tickets,
    required Iterable<Account> accounts,
    Set<String> pinnedProjects = const {},
    Set<String> pinnedExecutions = const {},
  }) {
    final byId = {for (final a in accounts) a.id: a};
    final counts = <String, int>{};
    void add(String key) => counts[key] = (counts[key] ?? 0) + 1;

    for (final t in tickets) {
      final account = byId[t.accountId];
      if (account == null ||
          !isOpenForAssignee(t) ||
          !const IsAssignedToMe()(t, account)) {
        continue;
      }
      final a = account.id;
      final counted = switch (t.providerEntity) {
        ZenTaoBugEntity(:final product) => _leaf(
          add,
          a,
          pinned: product != null && pinnedProjects.contains('$a:$product'),
          group: AssignedCounts.zentaoBugsKey(a),
          leaves: [
            if (product != null) AssignedCounts.zentaoProductKey(a, product),
          ],
        ),
        ZenTaoTaskEntity(:final execution, :final project) => _leaf(
          add,
          a,
          pinned:
              execution != null && pinnedExecutions.contains('$a:$execution'),
          group: AssignedCounts.zentaoTasksKey(a),
          leaves: [
            if (execution != null)
              AssignedCounts.zentaoExecutionKey(a, execution),
          ],
          // The project folder shows only the executions not pinned.
          unpinnedLeaves: [
            if (project != null) AssignedCounts.zentaoProjectKey(a, project),
          ],
        ),
        GitLabItemEntity(:final projectId) => _project(
          add,
          a,
          projectId?.toString(),
          pinnedProjects,
        ),
        GitHubItemEntity(:final repo) => _project(add, a, repo, pinnedProjects),
        _ => false,
      };
      if (!counted) continue;
      add(AssignedCounts.accountKey(a));
      add(AssignedCounts.workspaceKey(account.workspaceId));
      add(AssignedCounts.totalKey);
    }
    return AssignedCounts(Map.unmodifiable(counts));
  }

  /// Counts a ticket on its [leaves], and on "Pinned" or its [group] (with
  /// [unpinnedLeaves], the nodes that only hold what is not pinned).
  static bool _leaf(
    void Function(String key) add,
    String accountId, {
    required bool pinned,
    required String group,
    required List<String> leaves,
    List<String> unpinnedLeaves = const [],
  }) {
    leaves.forEach(add);
    if (pinned) {
      add(AssignedCounts.pinnedKey(accountId));
    } else {
      add(group);
      unpinnedLeaves.forEach(add);
    }
    return true;
  }

  /// A GitLab / GitHub item: on its project, and under "Pinned" or the
  /// projects group.
  static bool _project(
    void Function(String key) add,
    String accountId,
    String? projectId,
    Set<String> pinnedProjects,
  ) {
    return _leaf(
      add,
      accountId,
      pinned:
          projectId != null && pinnedProjects.contains('$accountId:$projectId'),
      group: AssignedCounts.projectsKey(accountId),
      leaves: [
        if (projectId != null) AssignedCounts.projectKey(accountId, projectId),
      ],
    );
  }
}
