part of 'board_providers.dart';

// GitHub sources: repository pull request / issue boards and their sidebar state.

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
      final res = await ref
          .watch(sourceSyncServiceProvider)
          .listProjects(accountId);
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
  final res = await ref
      .watch(sourceSyncServiceProvider)
      .syncGitHubRepoItems(
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
  final res = await ref
      .watch(sourceSyncServiceProvider)
      .syncGitHubMine(selection.accountId);
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});
