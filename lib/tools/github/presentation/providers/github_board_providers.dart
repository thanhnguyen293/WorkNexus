import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/github_pr_service.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/usecases/build_github_issue_board.dart';
import '../../domain/usecases/build_github_pr_board.dart';
import '../../domain/value_objects/github_item_kind.dart';

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

Stream<List<T>> _cachedThenFresh<T>(
  Future<List<T>?> cached,
  Future<Result<List<T>>> Function() fetch,
) async* {
  final stored = await cached;
  if (stored != null) yield stored;
  switch (await fetch()) {
    case Ok(:final value):
      yield value;
    case Err(:final failure):
      if (stored == null) throw failure;
  }
}

/// GitHub repos the account can access (the sidebar Repositories tree).
final githubReposProvider =
    StreamProvider.family<List<ProviderProject>, String>(
      (ref, accountId) => _cachedThenFresh(
        getIt<GitHubPrService>().cachedProjects(accountId),
        () => getIt<GitHubPrService>().listProjects(accountId),
      ),
    );

/// The selected repo + kind's server slice.
final githubItemsSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final repo = ref.watch(selectedGitHubRepoProvider);
  if (repo == null || repo.mine) return const <String>{};
  final kind = ref.watch(githubKindProvider);
  final res = await getIt<GitHubPrService>().syncGitHubRepoItems(
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

/// The account-wide "my pull requests" slice.
final githubMineSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final selection = ref.watch(selectedGitHubRepoProvider);
  if (selection == null || !selection.mine) return const <String>{};
  final res = await getIt<GitHubPrService>().syncGitHubMine(
    selection.accountId,
  );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

final githubPrBoardProvider = Provider<GitHubPrBoardModel>(
  (ref) => const BuildGitHubPrBoard()(ref.watch(boardQueryProvider)),
);

final githubIssueBoardProvider = Provider<GitHubIssueBoardModel>(
  (ref) => const BuildGitHubIssueBoard()(ref.watch(boardQueryProvider)),
);
