import 'dart:math' as math;

import '../../../../core/usecase/usecase.dart';
import '../entities/paged_view_state.dart';
import '../value_objects/paging_policy.dart';

/// A request to load more of a paged view.
class ViewLoadRequest {
  const ViewLoadRequest({
    required this.state,
    required this.filtered,
    this.visible,
  });

  final PagedViewState state;

  /// Whether the board's filter can hide loaded cards.
  final bool filtered;

  /// How many of the view's cards its column shows as it asks; null for a load
  /// the column did not ask for (a board opening, a retry).
  final int? visible;
}

/// Which pages to fetch, and the view's state while they load.
class ViewLoadPlan {
  const ViewLoadPlan({required this.pages, required this.loading});

  final List<int> pages;

  /// The view marked loading, with the column's ask recorded.
  final PagedViewState loading;
}

/// Plans the next load of a paged view; null when it cannot load (a page is
/// loading, the last failed, or there is none).
///
/// The first page tells the view's size, so only later loads fan out: a
/// filtered board fetches [kFilteredPagesPerLoad] pages side by side. A load a
/// column asks for counts towards its dry streak when no new card showed since
/// its last ask (see [ShouldAutoLoad]).
class PlanViewLoad extends UseCase<ViewLoadPlan?, ViewLoadRequest> {
  const PlanViewLoad();

  @override
  ViewLoadPlan? call(ViewLoadRequest r) {
    final state = r.state;
    if (!state.canLoadMore) return null;
    final visible = r.visible;
    final asked = visible == null
        ? state
        : state.copyWith(
            scanVisible: visible,
            dryLoads: visible == state.scanVisible ? state.dryLoads + 1 : 0,
          );
    final first = state.page + 1;
    final lastPage = (state.total / kPagedViewPageSize).ceil();
    final last = state.started && r.filtered
        ? math.min(first + kFilteredPagesPerLoad - 1, math.max(lastPage, first))
        : first;
    return ViewLoadPlan(
      pages: [for (var page = first; page <= last; page++) page],
      loading: asked.copyWith(loading: true),
    );
  }
}
