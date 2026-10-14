import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/error/result.dart';
import '../../../core/util/cancel_signal.dart';
import '../domain/entities/paged_view_state.dart';
import '../domain/usecases/apply_view_pages.dart';
import '../domain/usecases/plan_view_load.dart';
import '../domain/value_objects/paging_policy.dart';
import 'filter_providers.dart';

/// A board whose columns each page their own server view [V], loading further
/// pages as a column scrolls to its end. Subclasses say how a page is fetched
/// ([fetchPage], which also stores it locally — the board reads the tickets
/// from the database and keeps the ids loaded here); this class orchestrates:
/// [PlanViewLoad] picks the pages, [ApplyViewPages] folds them in.
///
/// Every rebuild (another product/execution, a refresh, a new order) starts
/// the views over and cancels the previous one's requests in flight.
abstract class PagedViewsController<V>
    extends Notifier<Map<V, PagedViewState>> {
  /// Bumped on every rebuild so a page that still arrives for the previous
  /// board is dropped.
  int _generation = 0;
  CancelSignal _cancel = CancelSignal();

  /// One [page] of [view], [limit] tickets per page.
  @protected
  Future<Result<ViewPage>> fetchPage(
    V view, {
    required int page,
    required int limit,
    required CancelSignal cancel,
  });

  /// Starts [views] over, loading the first page of each of [opening] at once;
  /// called from [build].
  @protected
  Map<V, PagedViewState> open({
    required Iterable<V> views,
    Iterable<V> opening = const [],
  }) {
    _generation++;
    final cancel = _cancel = CancelSignal();
    ref.onDispose(cancel.cancel);
    final first = opening.toList();
    if (first.isNotEmpty) {
      Future.microtask(() {
        for (final view in first) {
          loadMore(view);
        }
      });
    }
    return {for (final view in views) view: const PagedViewState()};
  }

  /// Loads the next pages of [view], unless it cannot load now. [visible] is
  /// how many of the view's cards its column shows when it asks — what tells a
  /// filtered column whether loading still turns up matches.
  Future<void> loadMore(V view, {int? visible}) async {
    final current = state[view];
    if (current == null) return;
    final plan = const PlanViewLoad()(
      ViewLoadRequest(
        state: current,
        filtered: ref.read(filterStateProvider).narrowsTickets,
        visible: visible,
      ),
    );
    if (plan == null) return;
    final generation = _generation;
    final cancel = _cancel;
    _set(view, plan.loading);
    final pages = await Future.wait([
      for (final page in plan.pages)
        fetchPage(view, page: page, limit: kPagedViewPageSize, cancel: cancel),
    ]);
    if (!ref.mounted || generation != _generation) return;
    _set(
      view,
      const ApplyViewPages()(
        ViewPagesResult(state: state[view] ?? plan.loading, pages: pages),
      ),
    );
  }

  /// Tries [view]'s failed page again.
  Future<void> retry(V view) {
    final current = state[view];
    if (current != null) _set(view, current.copyWith(failure: null));
    return loadMore(view);
  }

  void _set(V view, PagedViewState value) => state = {...state, view: value};
}
