import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';

part 'paged_view_state.freezed.dart';

/// What a board has loaded of one paged server view (a ZenTao bug view, a task
/// status): the ids so far and where its paging stands.
@freezed
abstract class PagedViewState with _$PagedViewState {
  const PagedViewState._();

  const factory PagedViewState({
    /// The ids of the tickets loaded so far.
    @Default(<String>{}) Set<String> ids,

    /// The last page loaded; 0 before the first.
    @Default(0) int page,

    /// How many tickets the view holds on the server, across every page.
    @Default(0) int total,
    @Default(true) bool hasMore,
    @Default(false) bool loading,

    /// Why the last page failed to load; cleared by a retry.
    Failure? failure,

    /// How many of the view's cards the board showed when its column last
    /// asked for more; -1 before it asked.
    @Default(-1) int scanVisible,

    /// How many loads in a row the column asked for without a new card
    /// showing since the one before.
    @Default(0) int dryLoads,
  }) = _PagedViewState;

  bool get started => page > 0;

  /// Whether the next page can be fetched: a failed page waits for a retry.
  bool get canLoadMore => hasMore && !loading && failure == null;
}
