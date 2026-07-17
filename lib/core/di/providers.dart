import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/fixtures/fixture_repositories.dart';
import '../../features/agents/data/cli_agent_adapters.dart';
import '../../features/agents/data/mock_coding_agent_adapter.dart';
import '../../features/agents/domain/adapters/coding_agent_adapter.dart';
import '../../features/connections/data/local_connection_repository.dart';
import '../../features/connections/domain/repositories/connection_repository.dart';
import '../../features/sync/data/sync_service.dart';
import '../../features/translation/data/mock_translation_service.dart';
import '../../features/translation/domain/adapters/translation_service.dart';
import '../database/database.dart';
import '../domain/entities/account.dart';
import '../domain/entities/project.dart';
import '../domain/entities/ticket.dart';
import '../domain/entities/workspace.dart';
import '../domain/repositories/activity_repository.dart';
import '../domain/repositories/agent_session_repository.dart';
import '../domain/repositories/comment_repository.dart';
import '../domain/repositories/dev_link_repository.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/repositories/translation_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../domain/value_objects/agent_kind.dart';
import '../platform/credential_store.dart';

/// The shared in-memory demo store. Still provides the mock-translation VI
/// source and the generated activity/dev-link data; the core ticket/workspace/
/// comment/translation repositories move to drift in Phase 4 via overrides.
final fixtureStoreProvider = Provider<FixtureStore>((ref) => FixtureStore());

/// The drift database. Overridden in `main()` with the real, seeded instance;
/// throws if a drift-backed repository is used without that override.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(
    'appDatabaseProvider must be overridden in main()',
  ),
);

/// Provider secrets in the OS keychain.
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

/// Persists provider connections (accounts) to drift.
final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => LocalConnectionRepository(ref.watch(appDatabaseProvider)),
);

/// Pulls tickets from a provider account into drift.
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(credentialStoreProvider),
  ),
);

// ---- Repository seam (override these to swap fixtures ↔ drift ↔ remote) ----

final ticketRepositoryProvider = Provider<TicketRepository>(
  (ref) => FixtureTicketRepository(ref.watch(fixtureStoreProvider)),
);

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => FixtureWorkspaceRepository(ref.watch(fixtureStoreProvider)),
);

final translationRepositoryProvider = Provider<TranslationRepository>(
  (ref) => FixtureTranslationRepository(ref.watch(fixtureStoreProvider)),
);

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => FixtureCommentRepository(ref.watch(fixtureStoreProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => FixtureActivityRepository(ref.watch(fixtureStoreProvider)),
);

final devLinkRepositoryProvider = Provider<DevLinkRepository>(
  (ref) => FixtureDevLinkRepository(ref.watch(fixtureStoreProvider)),
);

final agentSessionRepositoryProvider = Provider<AgentSessionRepository>(
  (ref) => FixtureAgentSessionRepository(),
);

/// Translation backend. Mock demo service; a real OpenCode-backed service can
/// be overridden in here without touching the UI.
final translationServiceProvider = Provider<TranslationService>(
  (ref) => MockTranslationService(ref.watch(fixtureStoreProvider).viByTicketId),
);

/// Dry-run (mock) agents vs the real installed CLIs. Defaults to dry-run so the
/// demo never spawns a process unless the user opts in.
final dryRunAgentsProvider = StateProvider<bool>((ref) => true);

/// AgentKind → adapter. Mock adapters in dry-run; the real `claude`/`codex`/
/// `opencode` CLI adapters otherwise.
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

// ---- Shared reactive reads ----

final ticketsProvider = StreamProvider<List<Ticket>>(
  (ref) => ref.watch(ticketRepositoryProvider).watchTickets(),
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
  (ref) => ref.watch(workspaceRepositoryProvider).watchWorkspaces(),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(workspaceRepositoryProvider).watchAccounts(),
);

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(workspaceRepositoryProvider).watchProjects(),
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
