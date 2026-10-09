part of 'board_providers.dart';

// GitLab sources: project merge request / issue boards and their sidebar state.

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

/// The selected project + kind's server slice: syncs that project's recent
/// issues/MRs into drift and returns their ids so the board renders just that
/// slice. Refetched on every project/kind change (autoDispose + reactive deps).
final gitlabItemsSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final project = ref.watch(selectedGitLabProjectProvider);
  if (project == null || project.mine) return const <String>{};
  final kind = ref.watch(gitlabKindProvider);
  final res = await ref
      .watch(sourceSyncServiceProvider)
      .syncGitLabProjectItems(
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
  final res = await ref
      .watch(sourceSyncServiceProvider)
      .syncGitLabMine(selection.accountId);
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});
