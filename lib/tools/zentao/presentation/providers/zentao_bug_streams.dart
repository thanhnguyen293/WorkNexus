import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/cancel_signal.dart';
import '../../../../shared/board/domain/entities/paged_view_state.dart';
import '../../../../shared/board/presentation/paged_views_controller.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import 'zentao_board_providers.dart';
import 'zentao_data_providers.dart';
import 'zentao_table_sort.dart';

/// The views loaded as soon as a product's bug board opens. [ZenTaoBugStream.all]
/// only feeds the Closed column, so it waits until that column is shown; on
/// the Assigned-to-me tab ([mine]) one view feeds every column.
List<ZenTaoBugStream> _openingStreams({required bool mine}) => mine
    ? const [ZenTaoBugStream.assignedToMe]
    : const [
        ZenTaoBugStream.unconfirmed,
        ZenTaoBugStream.unresolved,
        ZenTaoBugStream.toClose,
      ];

/// The selected product's bug views, each paged on its own as its columns
/// scroll to the end (see [PagedViewsController]).
class ZenTaoBugStreamsController extends PagedViewsController<ZenTaoBugStream> {
  @override
  Map<ZenTaoBugStream, PagedViewState> build() {
    // A new order starts every view over from its first page.
    ref.watch(zentaoBugFetchSortProvider);
    // So does moving to or from Assigned to me, which loads other views.
    final mine = ref.watch(zentaoBugMineProvider);
    // Bugs are listed per product only: without one there is nothing to page.
    final none = ref.watch(selectedZenTaoProductProvider) == null;
    return open(
      views: ZenTaoBugStream.values,
      opening: none ? const [] : _openingStreams(mine: mine),
      finished: none,
    );
  }

  @override
  Future<Result<ViewPage>> fetchPage(
    ZenTaoBugStream view, {
    required int page,
    required int limit,
    required CancelSignal cancel,
  }) async {
    final product = ref.read(selectedZenTaoProductProvider);
    if (product == null) {
      return const Err(CancelledFailure('No product is selected'));
    }
    return ref
        .read(zentaoViewPagesProvider)
        .syncProductBugsPage(
          accountId: product.accountId,
          productId: product.productId,
          browseType: view.code,
          page: page,
          limit: limit,
          sort: ref.read(zentaoBugFetchSortProvider),
          cancel: cancel,
        );
  }
}

final zentaoBugStreamsProvider =
    NotifierProvider.autoDispose<
      ZenTaoBugStreamsController,
      Map<ZenTaoBugStream, PagedViewState>
    >(ZenTaoBugStreamsController.new);

/// What has been loaded of the view [column] draws on.
final zentaoBugColumnStreamProvider = Provider.autoDispose
    .family<PagedViewState, ZenTaoBugColumn>(
      (ref, column) =>
          ref.watch(zentaoBugStreamsProvider)[ZenTaoBugStream.of(
            column,
            mine: ref.watch(zentaoBugMineProvider),
          )] ??
          const PagedViewState(),
    );

/// The ids of every bug the board's views have loaded — loading until each
/// opening view has its first page (the board shows the product's cached bugs
/// meanwhile), an error when none of them could be loaded.
final zentaoBugSliceProvider = Provider.autoDispose<AsyncValue<Set<String>>>((
  ref,
) {
  if (ref.watch(selectedZenTaoProductProvider) == null) {
    return const AsyncData(<String>{});
  }
  final streams = ref.watch(zentaoBugStreamsProvider);
  final opening = [
    for (final s in _openingStreams(mine: ref.watch(zentaoBugMineProvider)))
      ?streams[s],
  ];
  if (opening.every((s) => s.failure != null)) {
    final failure = opening.first.failure;
    if (failure != null) return AsyncError(failure, StackTrace.current);
  }
  if (opening.any((s) => !s.started && s.failure == null)) {
    return const AsyncLoading();
  }
  return AsyncData({for (final s in streams.values) ...s.ids});
});

/// Whether a column on screen can still load more bugs, now or once its failed
/// page is retried — the board then stays up even while every loaded bug is
/// filtered out (or none loaded), so its columns can fetch further pages and a
/// failed one shows its Retry.
final zentaoBugHasMoreProvider = Provider.autoDispose<bool>((ref) {
  final streams = ref.watch(zentaoBugStreamsProvider);
  final mine = ref.watch(zentaoBugMineProvider);
  final closedShown =
      ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all;
  // Only the views the columns on screen draw on: one not loaded yet counts
  // as having more.
  final shown = {
    for (final column in ZenTaoBugColumn.values)
      if (closedShown || column != ZenTaoBugColumn.closed)
        ZenTaoBugStream.of(column, mine: mine),
  };
  return shown.any((view) => streams[view]?.hasMore ?? false);
});
