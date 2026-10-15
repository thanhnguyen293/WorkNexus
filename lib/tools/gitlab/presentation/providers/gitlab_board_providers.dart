import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/usecases/build_gitlab_issue_board.dart';
import '../../domain/usecases/build_gitlab_mr_board.dart';
import '../../domain/value_objects/gitlab_item_kind.dart';

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

/// Which GitLab groups/subgroups (`accountId:fullPath`) are collapsed in the
/// navigation sidebar. Empty by default, so all groups start expanded.
class GitLabGroupsCollapsed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final next = Set<String>.of(state);
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }
}

final gitlabGroupsCollapsedProvider =
    NotifierProvider<GitLabGroupsCollapsed, Set<String>>(
      GitLabGroupsCollapsed.new,
    );

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

/// GitLab projects the account is a member of (the sidebar Projects tree).
final gitlabProjectsProvider =
    StreamProvider.family<List<ProviderProject>, String>(
      (ref, accountId) => _cachedThenFresh(
        getIt<GitLabMrService>().cachedProjects(accountId),
        () => getIt<GitLabMrService>().listProjects(accountId),
      ),
    );

/// The selected project + kind's server slice.
final gitlabItemsSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final project = ref.watch(selectedGitLabProjectProvider);
  if (project == null || project.mine) return const <String>{};
  final kind = ref.watch(gitlabKindProvider);
  final res = await getIt<GitLabMrService>().syncGitLabProjectItems(
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

/// The account-wide "my merge requests" slice.
final gitlabMineSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final selection = ref.watch(selectedGitLabProjectProvider);
  if (selection == null || !selection.mine) return const <String>{};
  final res = await getIt<GitLabMrService>().syncGitLabMine(
    selection.accountId,
  );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

final gitlabMrBoardProvider = Provider<GitLabMrBoardModel>(
  (ref) => const BuildGitLabMrBoard()(ref.watch(boardQueryProvider)),
);

final gitlabIssueBoardProvider = Provider<GitLabIssueBoardModel>(
  (ref) => const BuildGitLabIssueBoard()(ref.watch(boardQueryProvider)),
);
