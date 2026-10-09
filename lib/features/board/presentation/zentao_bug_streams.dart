import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../sync/data/sync_service.dart';
import '../domain/value_objects/zentao_bug_browse_type.dart';
import '../domain/value_objects/zentao_bug_column.dart';
import '../domain/value_objects/zentao_bug_stream.dart';
import 'board_providers.dart';

/// Bugs per page of a column's view: enough to fill a column, small enough
/// that the board shows up quickly.
const kZenTaoBugStreamPageSize = 50;

/// What the board has loaded of one [ZenTaoBugStream].
class ZenTaoBugStreamState {
  const ZenTaoBugStreamState({
    this.ids = const <String>{},
    this.page = 0,
    this.total = 0,
    this.hasMore = true,
    this.loading = false,
    this.failure,
  });

  /// The ids of the bugs loaded so far.
  final Set<String> ids;

  /// The last page loaded; 0 before the first.
  final int page;

  /// How many bugs the view holds on the server, across every page.
  final int total;
  final bool hasMore;
  final bool loading;

  /// Why the last page failed to load; cleared by a retry.
  final Failure? failure;

  bool get started => page > 0;

  /// Whether the next page should be fetched as soon as the column's end is
  /// shown: a failed page waits for a retry instead.
  bool get canLoadMore => hasMore && !loading && failure == null;

  ZenTaoBugStreamState copyWith({
    Set<String>? ids,
    int? page,
    int? total,
    bool? hasMore,
    bool? loading,
    Failure? Function()? failure,
  }) => ZenTaoBugStreamState(
    ids: ids ?? this.ids,
    page: page ?? this.page,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    failure: failure == null ? this.failure : failure(),
  );
}

/// The views loaded as soon as a product's bug board opens. [ZenTaoBugStream.all]
/// only feeds the Closed column, so it waits until that column is shown.
const _openingStreams = [
  ZenTaoBugStream.unconfirmed,
  ZenTaoBugStream.unresolved,
  ZenTaoBugStream.toClose,
];

/// The selected product's bug views, each paged on its own as its columns
/// scroll to the end. Pages are upserted into drift; the board reads the bugs
/// from there and keeps the ids loaded here (local-first).
class ZenTaoBugStreamsController
    extends Notifier<Map<ZenTaoBugStream, ZenTaoBugStreamState>> {
  /// Bumped on every rebuild (product switch, refresh) so a page that arrives
  /// for the previous product is dropped.
  int _generation = 0;

  @override
  Map<ZenTaoBugStream, ZenTaoBugStreamState> build() {
    _generation++;
    if (ref.watch(selectedZenTaoProductProvider) != null) {
      Future.microtask(() {
        for (final stream in _openingStreams) {
          loadMore(stream);
        }
      });
    }
    return {
      for (final stream in ZenTaoBugStream.values)
        stream: const ZenTaoBugStreamState(),
    };
  }

  /// Loads the next page of [stream], unless one is loading, the last failed
  /// or there is none.
  Future<void> loadMore(ZenTaoBugStream stream) async {
    final product = ref.read(selectedZenTaoProductProvider);
    final current = state[stream];
    if (product == null || current == null || !current.canLoadMore) return;
    final generation = _generation;
    _set(stream, current.copyWith(loading: true));
    final res = await getIt<SyncService>().syncProductBugsPage(
      accountId: product.accountId,
      productId: product.productId,
      browseType: stream.code,
      page: current.page + 1,
      limit: kZenTaoBugStreamPageSize,
    );
    if (!ref.mounted || generation != _generation) return;
    final now = state[stream] ?? current;
    _set(stream, switch (res) {
      Ok(:final value) => now.copyWith(
        ids: {...now.ids, for (final t in value.tickets) t.id},
        page: now.page + 1,
        total: value.total,
        hasMore: value.hasMore,
        loading: false,
      ),
      Err(:final failure) => now.copyWith(
        loading: false,
        failure: () => failure,
      ),
    });
  }

  /// Tries [stream]'s failed page again.
  Future<void> retry(ZenTaoBugStream stream) {
    final current = state[stream];
    if (current != null) _set(stream, current.copyWith(failure: () => null));
    return loadMore(stream);
  }

  void _set(ZenTaoBugStream stream, ZenTaoBugStreamState value) =>
      state = {...state, stream: value};
}

final zentaoBugStreamsProvider =
    NotifierProvider.autoDispose<
      ZenTaoBugStreamsController,
      Map<ZenTaoBugStream, ZenTaoBugStreamState>
    >(ZenTaoBugStreamsController.new);

/// What has been loaded of the view [column] draws on.
final zentaoBugColumnStreamProvider = Provider.autoDispose
    .family<ZenTaoBugStreamState, ZenTaoBugColumn>(
      (ref, column) =>
          ref.watch(zentaoBugStreamsProvider)[ZenTaoBugStream.of(column)] ??
          const ZenTaoBugStreamState(),
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
