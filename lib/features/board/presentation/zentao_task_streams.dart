import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/cancel_signal.dart';
import '../domain/entities/paged_view_state.dart';
import '../domain/value_objects/zentao_task_column.dart';
import 'board_providers.dart';

/// The selected execution's task status views — one per column — each paged on
/// its own as its column scrolls to the end (see [PagedViewsController]), so a
/// column of thousands of done or closed tasks never holds up the board.
class ZenTaoTaskStreamsController
    extends PagedViewsController<ZenTaoTaskColumn> {
  @override
  Map<ZenTaoTaskColumn, PagedViewState> build() {
    // A new order starts every view over from its first page.
    ref.watch(zentaoTaskFetchSortProvider);
    return open(
      views: ZenTaoTaskColumn.values,
      opening: ref.watch(selectedZenTaoExecutionProvider) == null
          ? const []
          : ZenTaoTaskColumn.values,
    );
  }

  @override
  Future<Result<ViewPage>> fetchPage(
    ZenTaoTaskColumn view, {
    required int page,
    required int limit,
    required CancelSignal cancel,
  }) async {
    final execution = ref.read(selectedZenTaoExecutionProvider);
    if (execution == null) {
      return const Err(CancelledFailure('No execution is selected'));
    }
    return ref
        .read(zentaoViewPagesProvider)
        .syncExecutionTasksPage(
          accountId: execution.accountId,
          executionId: execution.executionId,
          browseType: view.browseType,
          page: page,
          limit: limit,
          sort: ref.read(zentaoTaskFetchSortProvider),
          cancel: cancel,
        );
  }
}

final zentaoTaskStreamsProvider =
    NotifierProvider.autoDispose<
      ZenTaoTaskStreamsController,
      Map<ZenTaoTaskColumn, PagedViewState>
    >(ZenTaoTaskStreamsController.new);

/// What has been loaded of [column]'s status view.
final zentaoTaskColumnStreamProvider = Provider.autoDispose
    .family<PagedViewState, ZenTaoTaskColumn>(
      (ref, column) =>
          ref.watch(zentaoTaskStreamsProvider)[column] ??
          const PagedViewState(),
    );

/// The ids of every task the board's views have loaded — loading until each
/// view has its first page (the board shows the execution's cached tasks
/// meanwhile), an error when none of them could be loaded.
final zentaoTaskSliceProvider = Provider.autoDispose<AsyncValue<Set<String>>>((
  ref,
) {
  if (ref.watch(selectedZenTaoExecutionProvider) == null) {
    return const AsyncData(<String>{});
  }
  final streams = ref.watch(zentaoTaskStreamsProvider).values;
  if (streams.every((s) => s.failure != null)) {
    final failure = streams.first.failure;
    if (failure != null) return AsyncError(failure, StackTrace.current);
  }
  if (streams.any((s) => !s.started && s.failure == null)) {
    return const AsyncLoading();
  }
  return AsyncData({for (final s in streams) ...s.ids});
});

/// Whether a task column can still load more, now or once its failed page is
/// retried — the board then stays up even while every loaded task is filtered
/// out (or none loaded), so its columns can fetch further pages and a failed
/// one shows its Retry.
final zentaoTaskHasMoreProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(zentaoTaskStreamsProvider).values.any((s) => s.hasMore),
);
