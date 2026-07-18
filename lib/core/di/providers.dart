import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/agents/data/cli_agent_adapters.dart';
import '../../features/agents/data/mock_coding_agent_adapter.dart';
import '../../features/agents/domain/adapters/coding_agent_adapter.dart';
import '../domain/entities/account.dart';
import '../domain/entities/project.dart';
import '../domain/entities/ticket.dart';
import '../domain/entities/workspace.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../domain/value_objects/agent_kind.dart';
import 'service_locator.dart';

// Reactive Riverpod state only. The object graph (databases, repositories,
// services) is wired by the GetIt service locator (`service_locator.dart`) — the
// single composition root — and read here via `getIt<T>()`. This file holds the
// reactive reads and derived state layered on top of those services.

/// Dry-run (mock) agents vs the real installed CLIs. Defaults to dry-run so the
/// demo never spawns a process unless the user opts in.
final dryRunAgentsProvider = StateProvider<bool>((ref) => true);

/// AgentKind → adapter. Mock adapters in dry-run; the real `claude`/`codex`/
/// `opencode` CLI adapters otherwise. Reactive to [dryRunAgentsProvider].
final codingAgentRegistryProvider =
    Provider<Map<AgentKind, CodingAgentAdapter>>((ref) {
      if (ref.watch(dryRunAgentsProvider)) {
        return {for (final k in AgentKind.values) k: MockCodingAgentAdapter(k)};
      }
      return {
        AgentKind.claudeCode: ClaudeCodeAdapter(),
        AgentKind.codex: CodexAdapter(),
        AgentKind.opencode: OpenCodeCliAdapter(),
      };
    });

// ---- Shared reactive reads (drift streams via the service locator) ----

final ticketsProvider = StreamProvider<List<Ticket>>(
  (ref) => getIt<TicketRepository>().watchTickets(),
);

/// A single ticket from the reactive set (null while loading / not found).
final ticketByIdProvider = Provider.family<Ticket?, String>((ref, id) {
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  for (final t in tickets) {
    if (t.id == id) return t;
  }
  return null;
});

final workspacesProvider = StreamProvider<List<Workspace>>(
  (ref) => getIt<WorkspaceRepository>().watchWorkspaces(),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => getIt<WorkspaceRepository>().watchAccounts(),
);

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => getIt<WorkspaceRepository>().watchProjects(),
);

/// accountId → workspaceId (for workspace scoping in the board filter).
final accountWorkspaceProvider = Provider<Map<String, String>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return {for (final a in accounts) a.id: a.workspaceId};
});

/// Workspace ids in display order (for the List view sort).
final workspaceOrderProvider = Provider<List<String>>((ref) {
  final ws = ref.watch(workspacesProvider).asData?.value ?? const [];
  return ws.map((w) => w.id).toList();
});

/// Id → entity lookups for resolving a ticket's workspace/account/project.
typedef Lookups = ({
  Map<String, Account> accounts,
  Map<String, Workspace> workspaces,
  Map<String, Project> projects,
});

final lookupsProvider = Provider<Lookups>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  final workspaces = ref.watch(workspacesProvider).asData?.value ?? const [];
  final projects = ref.watch(projectsProvider).asData?.value ?? const [];
  return (
    accounts: {for (final a in accounts) a.id: a},
    workspaces: {for (final w in workspaces) w.id: w},
    projects: {for (final p in projects) p.id: p},
  );
});
