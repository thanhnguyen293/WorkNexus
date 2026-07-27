import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/error/result.dart';
import '../../sync/data/sync_service.dart';
import 'board_providers.dart';

/// Whether the active board is fetching from its provider — drives the toolbar
/// Refresh button's spinner. Only the active board's slice is watched, mirroring
/// the board page, so an off-screen board never keeps its autoDispose slice
/// alive.
final boardRefreshingProvider = Provider<bool>((ref) {
  switch (ref.watch(viewModeProvider)) {
    case ViewMode.zentaoBugs:
      return ref.watch(zentaoBugTabSliceProvider).isLoading;
    case ViewMode.zentaoTasks:
      return ref.watch(zentaoExecutionSyncingProvider) != null;
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
    case ViewMode.list:
      return false;
  }
});

/// Re-fetches the active board's slice from its provider — the toolbar's manual
/// Refresh.
///
/// Invalidating the slice provider is enough for GitLab/GitHub, but the ZenTao
/// slices are TTL-cached inside [SyncService], so their cache entry is dropped
/// first: without that, a refresh inside the TTL window would replay the cached
/// ids and never reach the server.
class RefreshBoard {
  const RefreshBoard(this._ref, this._sync);

  final Ref _ref;
  final SyncService _sync;

  /// Returns [Err] only for a failure this call can observe (the task board's
  /// direct sync). Slice fetches report their own failure through the board's
  /// slice error state.
  Future<Result<void>> call() async {
    switch (_ref.read(viewModeProvider)) {
      case ViewMode.zentaoBugs:
        final product = _ref.read(selectedZenTaoProductProvider);
        if (product == null) return const Ok(null);
        _sync.invalidateProductBugsTab(
          accountId: product.accountId,
          productId: product.productId,
          browseType: _ref.read(zentaoBugTabProvider).code,
        );
        _ref.invalidate(zentaoBugTabSliceProvider);
        return const Ok(null);
      case ViewMode.zentaoTasks:
        return _refreshExecutionTasks();
      case ViewMode.gitlab:
        final project = _ref.read(selectedGitLabProjectProvider);
        if (project == null) return const Ok(null);
        _ref.invalidate(
          project.mine ? gitlabMineSliceProvider : gitlabItemsSliceProvider,
        );
        return const Ok(null);
      case ViewMode.github:
        final repo = _ref.read(selectedGitHubRepoProvider);
        if (repo == null) return const Ok(null);
        _ref.invalidate(
          repo.mine ? githubMineSliceProvider : githubItemsSliceProvider,
        );
        return const Ok(null);
      case ViewMode.home:
      case ViewMode.board:
      case ViewMode.list:
        return const Ok(null);
    }
  }

  /// The task board has no slice provider — its tasks are pulled by the sidebar
  /// row that opens the execution — so a refresh re-runs that same sync and
  /// reuses its syncing indicator.
  Future<Result<void>> _refreshExecutionTasks() async {
    final selection = _ref.read(selectedZenTaoExecutionProvider);
    if (selection == null) return const Ok(null);
    final execution = ProviderExecution(
      id: selection.executionId,
      name: selection.executionName,
      projectId: selection.projectId,
      accountId: selection.accountId,
    );
    _sync.invalidateExecutionTasks(
      accountId: execution.accountId,
      executionId: execution.id,
    );
    _ref.read(zentaoExecutionSyncingProvider.notifier).start(execution);
    final res = await _sync.syncExecutionTasks(execution);
    if (_ref.mounted) {
      _ref.read(zentaoExecutionSyncingProvider.notifier).finish();
    }
    return switch (res) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}

final refreshBoardProvider = Provider<RefreshBoard>(
  (ref) => RefreshBoard(ref, getIt<SyncService>()),
);
