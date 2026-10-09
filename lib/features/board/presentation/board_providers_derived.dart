part of 'board_providers.dart';

// Derived board state: the scoped tickets, filters, facets and board models.

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
