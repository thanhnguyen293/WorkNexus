import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/cancel_signal.dart';
import '../../../../shared/board/domain/entities/paged_view_state.dart';
import '../../../../shared/board/domain/usecases/merge_view_pages.dart';
import '../../../../shared/board/presentation/paged_views_controller.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import 'zentao_board_providers.dart';
import 'zentao_data_providers.dart';
import 'zentao_table_sort.dart';

/// The views loaded as soon as a product's bug board opens. [ZenTaoBugStream.all]
/// only feeds the Closed column, so it waits until that column is shown; on
/// the Related-to-me tab ([related]) one merged view feeds every column.
List<ZenTaoBugStream> _openingStreams({required bool related}) => related
    ? const [ZenTaoBugStream.relatedToMe]
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
    ref.watch(boardRefreshTriggerProvider);
    // A new order starts every view over from its first page.
    ref.watch(zentaoBugFetchSortProvider);
    // So does moving to or from Assigned to me, which loads other views.
    final related = ref.watch(zentaoBugRelatedProvider);
    // Bugs are listed per product only: without one there is nothing to page.
    final none = ref.watch(selectedZenTaoProductProvider) == null;
    return open(
      views: ZenTaoBugStream.values,
      opening: none ? const [] : _openingStreams(related: related),
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
    final pages = ref.read(zentaoViewPagesProvider);
    final sort = ref.read(zentaoBugFetchSortProvider);
    Future<Result<ViewPage>> fetch(String code, int page) =>
        pages.syncProductBugsPage(
          accountId: product.accountId,
          productId: product.productId,
          browseType: code,
          page: page,
          limit: limit,
          sort: sort,
          cancel: cancel,
        );
    if (view.also.isEmpty) return fetch(view.code, page);
    // A view made of several (Related to me) is read whole, each of its views
    // to its own end, as one page. Paged together, page N of each would not
    // be the top of their merged order (a later page of one can sort before
    // an earlier page of another), and a view that ran out would be fetched
    // again: ZenTao answers a page past the end with its first.
    return const MergeViewPages()(
      await Future.wait([
        for (final code in view.codes) _wholeView((p) => fetch(code, p)),
      ]),
    );
  }

  /// Every page of one view, one after another, as a single last page.
  static Future<Result<ViewPage>> _wholeView(
    Future<Result<ViewPage>> Function(int page) fetch,
  ) async {
    final tickets = <Ticket>[];
    for (var page = 1; ; page++) {
      final res = await fetch(page);
      switch (res) {
        case Err():
          return res;
        case Ok(:final value):
          tickets.addAll(value.tickets);
          // An empty page ends it too: a view that claims more but sends
          // nothing must not be asked forever.
          if (!value.hasMore || value.tickets.isEmpty) {
            return Ok(
              ViewPage(tickets: tickets, total: value.total, hasMore: false),
            );
          }
      }
    }
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
            related: ref.watch(zentaoBugRelatedProvider),
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
    for (final s in _openingStreams(
      related: ref.watch(zentaoBugRelatedProvider),
    ))
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
  final related = ref.watch(zentaoBugRelatedProvider);
  final closedShown =
      ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all;
  // Only the views the columns on screen draw on: one not loaded yet counts
  // as having more.
  final shown = {
    for (final column in ZenTaoBugColumn.values)
      if (closedShown || column != ZenTaoBugColumn.closed)
        ZenTaoBugStream.of(column, related: related),
  };
  return shown.any((view) => streams[view]?.hasMore ?? false);
});
