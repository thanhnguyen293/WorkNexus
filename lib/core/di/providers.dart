import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/adapters/github_pr_service.dart';
import '../domain/adapters/gitlab_mr_service.dart';
import '../domain/adapters/opencode_cli.dart';
import '../domain/adapters/ticket_detail_service.dart';
import '../domain/adapters/zentao_ticket_editor.dart';
import '../domain/adapters/zentao_ticket_service.dart';
import '../domain/adapters/zentao_workflow_service.dart';
import '../domain/entities/account.dart';
import '../domain/entities/project.dart';
import '../domain/entities/ticket.dart';
import '../domain/entities/workspace.dart';
import '../domain/repositories/sync_status_repository.dart';
import '../domain/repositories/ticket_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../domain/usecases/resolve_zentao_ticket.dart';
import '../domain/value_objects/account_sync_status.dart';
import '../platform/desktop_notifier.dart';
import 'locator.dart';

// Reactive Riverpod state only. The object graph (databases, repositories,
// services) is wired by the GetIt service locator (`service_locator.dart`) — the
// single composition root — and read here via `getIt<T>()`. This file holds the
// reactive reads and derived state layered on top of those services.

// ---- Shared reactive reads (drift streams via the service locator) ----

/// OS notifications, one notifier for every feature that raises them (mini
/// apps, the ZenTao bell, …), so a test silences them all in one override.
final desktopNotifierProvider = Provider<DesktopNotifier>(
  (ref) => getIt<DesktopNotifier>(),
);

final ticketsProvider = StreamProvider<List<Ticket>>(
  (ref) => getIt<TicketRepository>().watchTickets(),
);

/// The reactive ticket set keyed by id, built once per emission so the
/// per-ticket lookups below cost a map read, not a scan of every ticket.
final ticketIndexProvider = Provider<Map<String, Ticket>>((ref) {
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  return {for (final t in tickets) t.id: t};
});

/// A single ticket from the reactive set (null while loading / not found).
/// Notifies only when that ticket changes (`Ticket` compares by value), not
/// on every emission of the set.
final ticketByIdProvider = Provider.autoDispose.family<Ticket?, String>(
  (ref, id) => ref.watch(ticketIndexProvider.select((index) => index[id])),
);

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

/// Reads and changes workspaces (rename, style) without the UI holding the
/// implementation.
final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => getIt<WorkspaceRepository>(),
);

/// Whether translations go through the user's own API key rather than the
/// OpenCode CLI — in which case OpenCode needs no linking first.
/// Overridden in `main.dart` with the actual repository check.
final translatesWithApiKeyProvider = FutureProvider.autoDispose<bool>(
  (ref) async => false,
);

/// Whether OpenCode is authenticated (`opencode auth login` has been run, or a
/// key was added to its own credential store). When true, translation uses OpenCode's
/// own provider/auth so it shows in usage.
///
/// `autoDispose` so, until it is linked, each translation re-asks the CLI: a
/// key added in Settings takes effect without an app restart.
final openCodeAuthedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authed = await getIt<OpenCodeCli>().hasAuthenticatedProvider();
  // Asking runs the CLI (a second or two): once linked, the answer is kept
  // rather than asked again on every translation. The provider can be disposed
  // while the CLI runs (its last listener left, or a hot restart), and a
  // disposed Ref throws on use.
  if (authed && ref.mounted) ref.keepAlive();
  return authed;
});

/// Loads a ZenTao ticket the board has not synced (one linked in chat, a
/// subtask's parent) so it can open in the detail panel.
final zenTaoTicketServiceProvider = Provider<ZenTaoTicketService>(
  (ref) => getIt<ZenTaoTicketService>(),
);

/// Finds a ZenTao ticket to open: synced, or fetched from ZenTao.
final resolveZenTaoTicketProvider = Provider<ResolveZenTaoTicket>(
  (ref) => ResolveZenTaoTicket(
    ref.watch(zenTaoTicketServiceProvider),
    isSynced: (id) => ref.read(ticketByIdProvider(id)) != null,
  ),
);

/// Creates and edits ZenTao bugs and tasks through ZenTao's own forms.
final zenTaoTicketEditorProvider = Provider<ZenTaoTicketEditor>(
  (ref) => getIt<ZenTaoTicketEditor>(),
);

/// ZenTao's status actions on bugs and tasks (confirm, close, start, finish…).
final zenTaoWorkflowServiceProvider = Provider<ZenTaoWorkflowService>(
  (ref) => getIt<ZenTaoWorkflowService>(),
);

/// GitLab MR actions and inspection.
final gitLabMrServiceProvider = Provider<GitLabMrService>(
  (ref) => getIt<GitLabMrService>(),
);

/// GitHub PR actions and inspection.
final gitHubPrServiceProvider = Provider<GitHubPrService>(
  (ref) => getIt<GitHubPrService>(),
);

/// Provider-agnostic ticket detail actions and attachment retrieval.
final ticketDetailServiceProvider = Provider<TicketDetailService>(
  (ref) => getIt<TicketDetailService>(),
);

/// Watches the real-time sync status for a given provider account.
final syncStatusProvider = StreamProvider.autoDispose
    .family<AccountSyncStatus, String>((ref, accountId) {
      return getIt<SyncStatusRepository>().watch(accountId);
    });

/// 1-minute ticker provider to refresh relative timestamp text (e.g., 'Synced 2m ago').
final syncTickerProvider = StreamProvider.autoDispose<int>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (i) => i);
});
