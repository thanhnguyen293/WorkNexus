import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/result.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../tools/github/presentation/providers/github_board_providers.dart';
import '../../tools/gitlab/presentation/providers/gitlab_board_providers.dart';
import '../../tools/zentao/presentation/providers/zentao_bug_streams.dart';
import '../../tools/zentao/presentation/providers/zentao_task_streams.dart';

/// Whether the active section board is fetching from its provider.
/// Keys off the active section (design §4).
final boardRefreshingProvider = Provider<bool>((ref) {
  final section = ref.watch(
    appNavProvider.select((s) => s.currentLocation?.section.value),
  );
  if (section == null) return false;

  switch (section) {
    case 'zentao.bugs':
      return ref.watch(zentaoBugSliceProvider).isLoading;
    case 'zentao.tasks':
      return ref.watch(zentaoTaskSliceProvider).isLoading;
    case 'gitlab.mrs':
    case 'gitlab.issues':
      return (ref.watch(selectedGitLabProjectProvider)?.mine ?? false)
          ? ref.watch(gitlabMineSliceProvider).isLoading
          : ref.watch(gitlabItemsSliceProvider).isLoading;
    case 'github.pulls':
    case 'github.issues':
      return (ref.watch(selectedGitHubRepoProvider)?.mine ?? false)
          ? ref.watch(githubMineSliceProvider).isLoading
          : ref.watch(githubItemsSliceProvider).isLoading;
    default:
      return false;
  }
});

/// Re-fetches the active section's slice from its provider — the toolbar's
/// manual Refresh. Invalidating the slice (or, for the paged ZenTao boards,
/// the streams) provider starts it over from the server.
class RefreshBoard {
  const RefreshBoard(this._ref);

  final Ref _ref;

  /// Slice fetches report their own failure through the board's slice error
  /// state, so this always returns [Ok].
  Future<Result<void>> call() async {
    final loc = _ref.read(currentToolLocationProvider);
    if (loc == null) return const Ok(null);

    switch (loc.section.value) {
      case 'zentao.bugs':
        // Starts every column's view over from its first page.
        _ref.invalidate(zentaoBugStreamsProvider);
      case 'zentao.tasks':
        _ref.invalidate(zentaoTaskStreamsProvider);
      case 'gitlab.mrs':
      case 'gitlab.issues':
        final project = _ref.read(selectedGitLabProjectProvider);
        if (project == null) return const Ok(null);
        _ref.invalidate(
          project.mine ? gitlabMineSliceProvider : gitlabItemsSliceProvider,
        );
      case 'github.pulls':
      case 'github.issues':
        final repo = _ref.read(selectedGitHubRepoProvider);
        if (repo == null) return const Ok(null);
        _ref.invalidate(
          repo.mine ? githubMineSliceProvider : githubItemsSliceProvider,
        );
      default:
        break;
    }
    return const Ok(null);
  }
}

final refreshBoardProvider = Provider<RefreshBoard>(RefreshBoard.new);
