import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/result.dart';
import '../../../core/util/synthetic_labels.dart';
import '../../sync/data/sync_service.dart';
import '../domain/entities/board_model.dart';
import '../domain/entities/filter_state.dart';
import '../domain/usecases/build_board.dart';
import '../domain/usecases/build_github_issue_board.dart';
import '../domain/usecases/build_github_pr_board.dart';
import '../domain/usecases/build_gitlab_issue_board.dart';
import '../domain/usecases/build_gitlab_mr_board.dart';
import '../domain/usecases/build_list.dart';
import '../domain/usecases/build_zentao_bug_board.dart';
import '../domain/usecases/build_zentao_task_board.dart';
import '../domain/usecases/derive_board_facets.dart';
import '../domain/usecases/filter_tickets.dart';
import '../domain/usecases/scope_provider_tickets.dart';
import '../domain/value_objects/github_item_kind.dart';
import '../domain/value_objects/gitlab_item_kind.dart';
import '../domain/value_objects/saved_view.dart';
import '../domain/value_objects/zentao_bug_browse_type.dart';

/// [home] is the launch state: no source is selected yet, so the main area
/// shows the welcome screen instead of a board. The user opens a real view by
/// picking a source from the sidebar.
enum ViewMode { home, board, zentaoBugs, zentaoTasks, gitlab, github, list }

class ZenTaoProductSelection {
  const ZenTaoProductSelection({
    required this.accountId,
    required this.productId,
    required this.productName,
  });

  final String accountId;
  final String productId;
  final String productName;
}

final viewModeProvider = NotifierProvider<ViewModeController, ViewMode>(
  ViewModeController.new,
);

class ViewModeController extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.home;
  void set(ViewMode m) => state = m;
}

/// Active filter selection + intent methods (the design's filter interactions).
class FilterController extends Notifier<FilterState> {
  @override
  FilterState build() => const FilterState();

  void setWorkspace(String id) {
    state = state.copyWith(workspaceId: id, accountIds: {}, projectIds: {});
    ref.read(boardLoadingProvider.notifier).pulse();
  }

  void setSavedView(SavedView v) => state = state.copyWith(savedView: v);
  void setSearch(String q) => state = state.copyWith(search: q);

  void toggleProvider(ProviderType p) =>
      state = state.copyWith(providers: _toggle(state.providers, p));
  void toggleAccount(String id) =>
      state = state.copyWith(accountIds: _toggle(state.accountIds, id));
  void toggleProject(String id) =>
      state = state.copyWith(projectIds: _toggle(state.projectIds, id));
  void toggleStatus(UnifiedStatus s) =>
      state = state.copyWith(statuses: _toggle(state.statuses, s));
  void togglePriority(Priority p) =>
      state = state.copyWith(priorities: _toggle(state.priorities, p));
  void toggleSeverity(int s) =>
      state = state.copyWith(severities: _toggle(state.severities, s));
  void toggleAssignee(String a) =>
      state = state.copyWith(assignees: _toggle(state.assignees, a));
  void toggleReviewer(String r) =>
      state = state.copyWith(reviewers: _toggle(state.reviewers, r));
  void toggleBugType(String t) =>
      state = state.copyWith(bugTypes: _toggle(state.bugTypes, t));
  void toggleResolution(String r) =>
      state = state.copyWith(resolutions: _toggle(state.resolutions, r));

  void clearAll() => state = state.copyWith(
    providers: {},
    accountIds: {},
    projectIds: {},
    statuses: {},
    priorities: {},
    severities: {},
    assignees: {},
    reviewers: {},
    bugTypes: {},
    resolutions: {},
    search: '',
  );

  /// Resets the chip filters to just "assigned to me" — the default applied when
  /// a ZenTao bug/task board opens. An empty [self] clears filters (shows all),
  /// so a board still opens cleanly when "me" can't be resolved.
  void showMine(String self) => state = state.copyWith(
    providers: {},
    accountIds: {},
    projectIds: {},
    statuses: {},
    priorities: {},
    severities: {},
    assignees: self.isEmpty ? {} : {self},
    reviewers: {},
    bugTypes: {},
    resolutions: {},
    search: '',
  );

  Set<T> _toggle<T>(Set<T> set, T value) {
    final next = Set<T>.of(set);
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }
}

final filterStateProvider = NotifierProvider<FilterController, FilterState>(
  FilterController.new,
);

/// Brief skeleton state on first load and workspace switches (design parity).
class BoardLoading extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _schedule();
    return true;
  }

  void pulse() {
    state = true;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 480), () {
      if (ref.mounted) state = false;
    });
  }
}

final boardLoadingProvider = NotifierProvider<BoardLoading, bool>(
  BoardLoading.new,
);

class TicketActionPending extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void start(String id) => state = {...state, id};

  void finish(String id) {
    final next = {...state}..remove(id);
    state = next;
  }
}

final ticketActionPendingProvider =
    NotifierProvider<TicketActionPending, Set<String>>(TicketActionPending.new);

/// Which ZenTao accounts have their collapsible "Projects" group expanded.
/// Empty by default, so every group starts collapsed.
class ZenTaoProjectsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final zentaoProjectsExpandedProvider =
    NotifierProvider<ZenTaoProjectsExpanded, Set<String>>(
      ZenTaoProjectsExpanded.new,
    );

class SelectedZenTaoProduct extends Notifier<ZenTaoProductSelection?> {
  @override
  ZenTaoProductSelection? build() => null;

  void select(ProviderProduct product) {
    state = ZenTaoProductSelection(
      accountId: product.accountId,
      productId: product.id,
      productName: product.name,
    );
  }

  void clear() => state = null;
}

final selectedZenTaoProductProvider =
    NotifierProvider<SelectedZenTaoProduct, ZenTaoProductSelection?>(
      SelectedZenTaoProduct.new,
    );

/// The selected bug-board tab (ZenTao browse type). Defaults to [unclosed],
/// matching ZenTao's own bug board; reset when switching products.
class ZenTaoBugTabController extends Notifier<ZenTaoBugBrowseType> {
  @override
  ZenTaoBugBrowseType build() => ZenTaoBugBrowseType.unclosed;

  void set(ZenTaoBugBrowseType tab) => state = tab;
  void reset() => state = ZenTaoBugBrowseType.unclosed;
}

final zentaoBugTabProvider =
    NotifierProvider<ZenTaoBugTabController, ZenTaoBugBrowseType>(
      ZenTaoBugTabController.new,
    );

/// The active bug tab's server slice: the ids of the bugs ZenTao returns for the
/// selected product + [zentaoBugTabProvider] browse type. Refetched on every tab
/// switch (autoDispose + reactive deps), and upserts those bugs into drift so
/// the board still renders from the DB (local-first). Empty off a product board.
final zentaoBugTabSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final product = ref.watch(selectedZenTaoProductProvider);
  if (product == null) return const <String>{};
  final tab = ref.watch(zentaoBugTabProvider);
  final res = await getIt<SyncService>().syncProductBugsTab(
    accountId: product.accountId,
    productId: product.productId,
    browseType: tab.code,
  );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

class ZenTaoExecutionSelection {
  const ZenTaoExecutionSelection({
    required this.accountId,
    required this.executionId,
    required this.executionName,
  });

  final String accountId;
  final String executionId;
  final String executionName;
}

class ZenTaoExecutionSyncing extends Notifier<String?> {
  @override
  String? build() => null;

  void start(ProviderExecution execution) =>
      state = '${execution.accountId}:${execution.id}';
  void finish() => state = null;
}

final zentaoExecutionSyncingProvider =
    NotifierProvider<ZenTaoExecutionSyncing, String?>(
      ZenTaoExecutionSyncing.new,
    );

class SelectedZenTaoExecution extends Notifier<ZenTaoExecutionSelection?> {
  @override
  ZenTaoExecutionSelection? build() => null;

  void select(ProviderExecution execution) {
    state = ZenTaoExecutionSelection(
      accountId: execution.accountId,
      executionId: execution.id,
      executionName: execution.name,
    );
  }

  void clear() => state = null;
}

final selectedZenTaoExecutionProvider =
    NotifierProvider<SelectedZenTaoExecution, ZenTaoExecutionSelection?>(
      SelectedZenTaoExecution.new,
    );

/// Which ZenTao accounts have their collapsible "Executions" group expanded.
/// Empty by default, so every group starts collapsed.
class ZenTaoExecutionsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final zentaoExecutionsExpandedProvider =
    NotifierProvider<ZenTaoExecutionsExpanded, Set<String>>(
      ZenTaoExecutionsExpanded.new,
    );

/// Which ZenTao projects (`accountId:projectId`) have their execution list
/// expanded in the sidebar's Executions tree. Collapsed by default.
class ZenTaoExecutionProjectsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final next = Set<String>.of(state);
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }
}

final zentaoExecutionProjectsExpandedProvider =
    NotifierProvider<ZenTaoExecutionProjectsExpanded, Set<String>>(
      ZenTaoExecutionProjectsExpanded.new,
    );

final zentaoProductsProvider =
    FutureProvider.family<List<ProviderProduct>, String>((
      ref,
      accountId,
    ) async {
      final res = await getIt<SyncService>().listProducts(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

final zentaoProjectsProvider =
    FutureProvider.family<List<ProviderProject>, String>((
      ref,
      accountId,
    ) async {
      final res = await getIt<SyncService>().listProjects(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

/// The connected ZenTao user's account handle (login) for [accountId] — the exact
/// value `Ticket.assignee` normalizes to (see `accountHandle` in the ZenTao
/// normalizer) — used as the default "my tickets" board filter. Empty when
/// unknown, in which case the board opens unfiltered.
final zentaoSelfHandleProvider = Provider.family<String, String>((
  ref,
  accountId,
) {
  return ref.watch(lookupsProvider).accounts[accountId]?.handle ?? '';
});

typedef ZenTaoExecutionsKey = ({String accountId, String projectId});

final zentaoExecutionsProvider =
    FutureProvider.family<List<ProviderExecution>, ZenTaoExecutionsKey>((
      ref,
      key,
    ) async {
      final res = await getIt<SyncService>().listProjectExecutions(
        key.accountId,
        key.projectId,
      );
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

// ---- GitLab dedicated board (project → issues/MRs) ----

class GitLabProjectSelection {
  const GitLabProjectSelection({
    required this.accountId,
    required this.projectId,
    required this.projectName,
    this.mine = false,
  });

  final String accountId;
  final String projectId;
  final String projectName;

  /// True for the account-wide "my merge requests" board (assigned + review
  /// across all projects) rather than a single project.
  final bool mine;
}

/// The GitLab project whose dedicated board is open (null off the GitLab board).
class SelectedGitLabProject extends Notifier<GitLabProjectSelection?> {
  @override
  GitLabProjectSelection? build() => null;

  void select(ProviderProject project) {
    state = GitLabProjectSelection(
      accountId: project.accountId,
      projectId: project.id,
      projectName: project.name,
    );
  }

  /// Open the account-wide "my merge requests" board (all projects).
  void selectMine(String accountId) {
    state = GitLabProjectSelection(
      accountId: accountId,
      projectId: '',
      projectName: '',
      mine: true,
    );
  }

  void clear() => state = null;
}

final selectedGitLabProjectProvider =
    NotifierProvider<SelectedGitLabProject, GitLabProjectSelection?>(
      SelectedGitLabProject.new,
    );

/// Which kind the GitLab board shows: Merge Requests (default) or Issues.
class GitLabKindController extends Notifier<GitLabItemKind> {
  @override
  GitLabItemKind build() => GitLabItemKind.mergeRequest;

  void set(GitLabItemKind kind) => state = kind;
}

final gitlabKindProvider =
    NotifierProvider<GitLabKindController, GitLabItemKind>(
      GitLabKindController.new,
    );

/// Which GitLab accounts have their collapsible "Projects" group expanded.
class GitLabProjectsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final gitlabProjectsExpandedProvider =
    NotifierProvider<GitLabProjectsExpanded, Set<String>>(
      GitLabProjectsExpanded.new,
    );

/// GitLab projects the account is a member of (the sidebar Projects tree).
final gitlabProjectsProvider =
    FutureProvider.family<List<ProviderProject>, String>((
      ref,
      accountId,
    ) async {
      final res = await getIt<SyncService>().listProjects(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

/// The selected project + kind's server slice: syncs that project's recent
/// issues/MRs into drift and returns their ids so the board renders just that
/// slice. Refetched on every project/kind change (autoDispose + reactive deps).
final gitlabItemsSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final project = ref.watch(selectedGitLabProjectProvider);
  if (project == null || project.mine) return const <String>{};
  final kind = ref.watch(gitlabKindProvider);
  final res = await getIt<SyncService>().syncGitLabProjectItems(
    accountId: project.accountId,
    projectId: project.projectId,
    mergeRequests: kind == GitLabItemKind.mergeRequest,
  );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

/// The account-wide "my merge requests" slice (assigned + review across all
/// projects): syncs them into drift and returns their ids. Active only when the
/// GitLab "mine" board is selected.
final gitlabMineSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final selection = ref.watch(selectedGitLabProjectProvider);
  if (selection == null || !selection.mine) return const <String>{};
  final res = await getIt<SyncService>().syncGitLabMine(selection.accountId);
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

/// Tickets scoped to the active ZenTao product/execution or GitLab project
/// selection, before the user's chip filters. Facets are derived from this set
/// so chip options and counts stay stable while filters toggle.
final _scopedTicketsProvider = Provider<List<Ticket>>((ref) {
  var tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  final gitlabProject = ref.watch(selectedGitLabProjectProvider);
  if (gitlabProject != null) {
    if (gitlabProject.mine) {
      // The account-wide "my merge requests" board: MRs assigned to me or
      // awaiting my review, across all projects — scoped by the `gitlab-mine`
      // label so it renders from cache offline, reconciled by the slice ids.
      final slice = ref.watch(gitlabMineSliceProvider).asData?.value;
      return const ScopeProviderTickets()(
        tickets: tickets,
        accountId: gitlabProject.accountId,
        providerType: ProviderType.gitlab,
        externalType: GitLabItemKind.mergeRequest.externalType,
        membershipLabel: gitlabMineLabel(gitlabProject.accountId),
        slice: slice,
      );
    }
    final kind = ref.watch(gitlabKindProvider);
    // The active project+kind's server slice (ids), or null while it is still
    // loading / has failed — offline-first: fall back to the cached tickets
    // tagged with this project's label, then reconcile once the slice resolves.
    final slice = ref.watch(gitlabItemsSliceProvider).asData?.value;
    return const ScopeProviderTickets()(
      tickets: tickets,
      accountId: gitlabProject.accountId,
      providerType: ProviderType.gitlab,
      externalType: kind.externalType,
      membershipLabel: gitlabProjectLabel(gitlabProject.projectId),
      slice: slice,
    );
  }
  final githubRepo = ref.watch(selectedGitHubRepoProvider);
  if (githubRepo != null) {
    if (githubRepo.mine) {
      // The account-wide "my pull requests" board: PRs assigned to me or
      // requesting my review, across all repos — scoped by the `github-mine`
      // label so it renders from cache offline, reconciled by the slice ids.
      final slice = ref.watch(githubMineSliceProvider).asData?.value;
      return const ScopeProviderTickets()(
        tickets: tickets,
        accountId: githubRepo.accountId,
        providerType: ProviderType.github,
        externalType: GitHubItemKind.pullRequest.externalType,
        membershipLabel: githubMineLabel(githubRepo.accountId),
        slice: slice,
      );
    }
    final kind = ref.watch(githubKindProvider);
    // The active repo+kind's server slice (ids), or null while it is still
    // loading / has failed — offline-first: fall back to the cached tickets
    // tagged with this repo's label, then reconcile once the slice resolves.
    final slice = ref.watch(githubItemsSliceProvider).asData?.value;
    return const ScopeProviderTickets()(
      tickets: tickets,
      accountId: githubRepo.accountId,
      providerType: ProviderType.github,
      externalType: kind.externalType,
      membershipLabel: githubRepoLabel(githubRepo.repoId),
      slice: slice,
    );
  }
  final product = ref.watch(selectedZenTaoProductProvider);
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  if (execution != null) {
    final executionLabel = zentaoExecutionLabel(execution.executionId);
    tickets = tickets
        .where(
          (ticket) =>
              ticket.accountId == execution.accountId &&
              (ticket.externalType ?? '').toLowerCase() == 'task' &&
              ticket.labels.contains(executionLabel),
        )
        .toList();
  } else if (product != null) {
    // The active bug tab's server slice (ids), or null while it is still
    // loading / has failed — offline-first: fall back to the cached bugs tagged
    // with this product's label, then reconcile once the slice resolves.
    final slice = ref.watch(zentaoBugTabSliceProvider).asData?.value;
    tickets = const ScopeProviderTickets()(
      tickets: tickets,
      accountId: product.accountId,
      providerType: ProviderType.zentao,
      externalType: 'bug',
      membershipLabel: zentaoProductLabel(product.productId),
      slice: slice,
    );
  }
  return tickets;
});

/// The query fed to the pure board/list use cases.
final _boardQueryProvider = Provider<BoardQuery>((ref) {
  return BoardQuery(
    tickets: ref.watch(_scopedTicketsProvider),
    filter: ref.watch(filterStateProvider),
    accountWorkspace: ref.watch(accountWorkspaceProvider),
    workspaceOrder: ref.watch(workspaceOrderProvider),
    now: DateTime.now(),
  );
});

/// The provider/account/project values actually present in the current board's
/// scope (before chip filters). The cross-provider filter uses this so a
/// GitLab/GitHub or "my MRs" board only offers that provider, its account, and
/// the projects on screen — never the whole workspace or unconnected providers.
typedef GenericFilterScope = ({
  Set<ProviderType> providers,
  Set<String> accountIds,
  Set<String> projectIds,
});

final genericFilterScopeProvider = Provider<GenericFilterScope>((ref) {
  final tickets = ref.watch(_scopedTicketsProvider);
  final providers = <ProviderType>{};
  final accountIds = <String>{};
  final projectIds = <String>{};
  for (final t in tickets) {
    providers.add(t.providerType);
    accountIds.add(t.accountId);
    projectIds.add(t.projectId);
  }
  return (providers: providers, accountIds: accountIds, projectIds: projectIds);
});

/// Whether the filter popover would render any actionable group for the current
/// board — the "Filters" button is hidden when this is false (nothing to
/// filter, e.g. a single-project "my MRs" board). Mirrors the popover's group
/// visibility: `FilterGroup` hides at <= 1 option, and the "mine" board shows
/// only the project group.
final filterHasGroupsProvider = Provider<bool>((ref) {
  switch (ref.watch(viewModeProvider)) {
    case ViewMode.zentaoBugs:
    case ViewMode.zentaoTasks:
    case ViewMode.gitlab:
      if (ref.watch(viewModeProvider) == ViewMode.gitlab &&
          ref.watch(gitlabKindProvider) != GitLabItemKind.mergeRequest) {
        return true;
      }
      return ref
          .watch(boardFacetsProvider)
          .groups
          .any((g) => g.options.length >= 2);
    case ViewMode.home:
    case ViewMode.board:
    case ViewMode.github:
    case ViewMode.list:
      final mineBoard =
          (ref.watch(selectedGitLabProjectProvider)?.mine ?? false) ||
          (ref.watch(selectedGitHubRepoProvider)?.mine ?? false);
      // Off the "mine" board, status + priority always offer >= 2 options.
      if (!mineBoard) return true;
      return ref.watch(genericFilterScopeProvider).projectIds.length >= 2;
  }
});

/// Available filter facets for the current ZenTao board (empty off-ZenTao).
final boardFacetsProvider = Provider<BoardFacets>((ref) {
  final scope = switch (ref.watch(viewModeProvider)) {
    ViewMode.zentaoBugs => BoardFacetScope.bug,
    ViewMode.zentaoTasks => BoardFacetScope.task,
    ViewMode.gitlab =>
      ref.watch(gitlabKindProvider) == GitLabItemKind.mergeRequest
          ? BoardFacetScope.gitlabMergeRequest
          : BoardFacetScope.none,
    ViewMode.home ||
    ViewMode.board ||
    ViewMode.github ||
    ViewMode.list => BoardFacetScope.none,
  };
  if (scope == BoardFacetScope.none) return BoardFacets.empty;
  return const DeriveBoardFacets()(
    BoardFacetsInput(tickets: ref.watch(_scopedTicketsProvider), scope: scope),
  );
});

final boardProvider = Provider<BoardModel>(
  (ref) => const BuildBoard()(ref.watch(_boardQueryProvider)),
);

final zentaoBugBoardProvider = Provider<ZenTaoBugBoardModel>(
  (ref) => const BuildZenTaoBugBoard()(ref.watch(_boardQueryProvider)),
);

final zentaoTaskBoardProvider = Provider<ZenTaoTaskBoardModel>(
  (ref) => const BuildZenTaoTaskBoard()(ref.watch(_boardQueryProvider)),
);

final gitlabMrBoardProvider = Provider<GitLabMrBoardModel>(
  (ref) => const BuildGitLabMrBoard()(ref.watch(_boardQueryProvider)),
);

final gitlabIssueBoardProvider = Provider<GitLabIssueBoardModel>(
  (ref) => const BuildGitLabIssueBoard()(ref.watch(_boardQueryProvider)),
);

// ---- GitHub dedicated board (repo → issues/PRs) ----

class GitHubRepoSelection {
  const GitHubRepoSelection({
    required this.accountId,
    required this.repoId,
    required this.repoName,
    this.mine = false,
  });

  final String accountId;

  /// The `owner/name` repo slug.
  final String repoId;
  final String repoName;

  /// True for the account-wide "my pull requests" board (assigned + review
  /// across all repos) rather than a single repo.
  final bool mine;
}

/// The GitHub repo whose dedicated board is open (null off the GitHub board).
class SelectedGitHubRepo extends Notifier<GitHubRepoSelection?> {
  @override
  GitHubRepoSelection? build() => null;

  void select(ProviderProject repo) {
    state = GitHubRepoSelection(
      accountId: repo.accountId,
      repoId: repo.id,
      repoName: repo.name,
    );
  }

  /// Open the account-wide "my pull requests" board (all repos).
  void selectMine(String accountId) {
    state = GitHubRepoSelection(
      accountId: accountId,
      repoId: '',
      repoName: '',
      mine: true,
    );
  }

  void clear() => state = null;
}

final selectedGitHubRepoProvider =
    NotifierProvider<SelectedGitHubRepo, GitHubRepoSelection?>(
      SelectedGitHubRepo.new,
    );

/// Which kind the GitHub board shows: Issues (default) or Pull Requests.
class GitHubKindController extends Notifier<GitHubItemKind> {
  @override
  GitHubItemKind build() => GitHubItemKind.issue;

  void set(GitHubItemKind kind) => state = kind;
}

final githubKindProvider =
    NotifierProvider<GitHubKindController, GitHubItemKind>(
      GitHubKindController.new,
    );

/// Which GitHub accounts have their collapsible "Repositories" group expanded.
class GitHubReposExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final githubReposExpandedProvider =
    NotifierProvider<GitHubReposExpanded, Set<String>>(GitHubReposExpanded.new);

/// GitHub repos the account can access (the sidebar Repositories tree).
final githubReposProvider =
    FutureProvider.family<List<ProviderProject>, String>((
      ref,
      accountId,
    ) async {
      final res = await getIt<SyncService>().listProjects(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

/// The selected repo + kind's server slice: syncs that repo's recent issues/PRs
/// into drift and returns their ids so the board renders just that slice.
/// Refetched on every repo/kind change (autoDispose + reactive deps).
final githubItemsSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final repo = ref.watch(selectedGitHubRepoProvider);
  if (repo == null || repo.mine) return const <String>{};
  final kind = ref.watch(githubKindProvider);
  final res = await getIt<SyncService>().syncGitHubRepoItems(
    accountId: repo.accountId,
    repoId: repo.repoId,
    pullRequests: kind == GitHubItemKind.pullRequest,
  );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

/// The account-wide "my pull requests" slice (assigned + review across all
/// repos): syncs them into drift and returns their ids. Active only when the
/// GitHub "mine" board is selected.
final githubMineSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final selection = ref.watch(selectedGitHubRepoProvider);
  if (selection == null || !selection.mine) return const <String>{};
  final res = await getIt<SyncService>().syncGitHubMine(selection.accountId);
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

final githubPrBoardProvider = Provider<GitHubPrBoardModel>(
  (ref) => const BuildGitHubPrBoard()(ref.watch(_boardQueryProvider)),
);

final githubIssueBoardProvider = Provider<GitHubIssueBoardModel>(
  (ref) => const BuildGitHubIssueBoard()(ref.watch(_boardQueryProvider)),
);

final listRowsProvider = Provider<List<Ticket>>(
  (ref) => const BuildList()(ref.watch(_boardQueryProvider)),
);

final resultCountProvider = Provider<int>((ref) {
  if (ref.watch(viewModeProvider) == ViewMode.gitlab) {
    return ref.watch(gitlabKindProvider) == GitLabItemKind.mergeRequest
        ? ref.watch(gitlabMrBoardProvider).total
        : ref.watch(gitlabIssueBoardProvider).total;
  }
  if (ref.watch(viewModeProvider) == ViewMode.github) {
    return ref.watch(githubKindProvider) == GitHubItemKind.pullRequest
        ? ref.watch(githubPrBoardProvider).total
        : ref.watch(githubIssueBoardProvider).total;
  }
  if (ref.watch(viewModeProvider) == ViewMode.zentaoBugs) {
    return ref.watch(zentaoBugBoardProvider).total;
  }
  if (ref.watch(viewModeProvider) == ViewMode.zentaoTasks) {
    return ref.watch(zentaoTaskBoardProvider).total;
  }
  final q = ref.watch(_boardQueryProvider);
  return const FilterTickets()(q).length;
});
