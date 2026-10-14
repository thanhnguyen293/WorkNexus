import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/util/cancel_signal.dart';
import '../domain/entities/paged_view_state.dart';
import '../domain/value_objects/zentao_bug_browse_type.dart';
import '../domain/value_objects/zentao_bug_column.dart';
import '../domain/value_objects/zentao_bug_stream.dart';
import 'board_providers.dart';

/// The views loaded as soon as a product's bug board opens. [ZenTaoBugStream.all]
/// only feeds the Closed column, so it waits until that column is shown.
const _openingStreams = [
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
    return open(
      views: ZenTaoBugStream.values,
      opening: ref.watch(selectedZenTaoProductProvider) == null
          ? const []
          : _openingStreams,
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
          ref.watch(zentaoBugStreamsProvider)[ZenTaoBugStream.of(column)] ??
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
  final opening = [for (final s in _openingStreams) ?streams[s]];
  if (opening.every((s) => s.failure != null)) {
    final failure = opening.first.failure;
    if (failure != null) return AsyncError(failure, StackTrace.current);
  }
  if (opening.any((s) => !s.started && s.failure == null)) {
    return const AsyncLoading();
  }
  return AsyncData({for (final s in streams.values) ...s.ids});
});

/// Whether a column on screen can still load more bugs — the board then stays
/// up even while every loaded bug is filtered out, so its columns can fetch
/// further pages.
final zentaoBugHasMoreProvider = Provider.autoDispose<bool>((ref) {
  final streams = ref.watch(zentaoBugStreamsProvider);
  final closedShown =
      ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all;
  return streams.entries.any(
    (e) =>
        (closedShown || e.key != ZenTaoBugStream.all) &&
        e.value.hasMore &&
        e.value.failure == null,
  );
});
