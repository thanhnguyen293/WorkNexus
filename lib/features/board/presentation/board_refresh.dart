import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import 'board_providers.dart';

/// Whether the active board is fetching from its provider — drives the toolbar
/// Refresh button's spinner. Only the active board's slice is watched, mirroring
/// the board page, so an off-screen board never keeps its autoDispose slice
/// alive.
final boardRefreshingProvider = Provider<bool>((ref) {
  switch (ref.watch(viewModeProvider)) {
    case ViewMode.zentaoBugs:
      return ref.watch(zentaoBugSliceProvider).isLoading;
    case ViewMode.zentaoTasks:
      return ref.watch(zentaoTaskSliceProvider).isLoading;
    case ViewMode.gitlab:
      return (ref.watch(selectedGitLabProjectProvider)?.mine ?? false)
          ? ref.watch(gitlabMineSliceProvider).isLoading
          : ref.watch(gitlabItemsSliceProvider).isLoading;
    case ViewMode.github:
      return (ref.watch(selectedGitHubRepoProvider)?.mine ?? false)
          ? ref.watch(githubMineSliceProvider).isLoading
          : ref.watch(githubItemsSliceProvider).isLoading;
    case ViewMode.home:
    case ViewMode.board:
      return false;
  }
});

/// Re-fetches the active board's slice from its provider — the toolbar's manual
/// Refresh. Invalidating the slice (or, for the paged ZenTao boards, the
/// streams) provider starts it over from the server.
class RefreshBoard {
  const RefreshBoard(this._ref);

  final Ref _ref;

  /// Slice fetches report their own failure through the board's slice error
  /// state, so this always returns [Ok].
  Future<Result<void>> call() async {
    switch (_ref.read(viewModeProvider)) {
      case ViewMode.zentaoBugs:
        // Starts every column's view over from its first page.
        _ref.invalidate(zentaoBugStreamsProvider);
      case ViewMode.zentaoTasks:
        _ref.invalidate(zentaoTaskStreamsProvider);
      case ViewMode.gitlab:
        final project = _ref.read(selectedGitLabProjectProvider);
        if (project == null) return const Ok(null);
        _ref.invalidate(
          project.mine ? gitlabMineSliceProvider : gitlabItemsSliceProvider,
        );
      case ViewMode.github:
        final repo = _ref.read(selectedGitHubRepoProvider);
        if (repo == null) return const Ok(null);
        _ref.invalidate(
          repo.mine ? githubMineSliceProvider : githubItemsSliceProvider,
        );
      case ViewMode.home:
      case ViewMode.board:
        break;
    }
    return const Ok(null);
  }
}

final refreshBoardProvider = Provider<RefreshBoard>(RefreshBoard.new);
