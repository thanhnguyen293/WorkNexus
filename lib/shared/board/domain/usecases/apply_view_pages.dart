import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/paged_view_state.dart';

/// A view's state and the pages a load fetched for it, in page order.
class ViewPagesResult {
  const ViewPagesResult({required this.state, required this.pages});

  final PagedViewState state;
  final List<Result<ViewPage>> pages;
}

/// Folds a load's pages into its view: their ids, the view's total and
/// whether more follow. A failed page keeps the pages before it and records
/// the failure, so paging resumes from it on retry.
class ApplyViewPages extends UseCase<PagedViewState, ViewPagesResult> {
  const ApplyViewPages();

  @override
  PagedViewState call(ViewPagesResult r) {
    var next = r.state;
    for (final res in r.pages) {
      switch (res) {
        case Ok(:final value):
          next = next.copyWith(
            ids: {...next.ids, for (final t in value.tickets) t.id},
            page: next.page + 1,
            total: value.total,
            hasMore: value.hasMore,
          );
        case Err(:final failure):
          return next.copyWith(loading: false, failure: failure);
      }
    }
    return next.copyWith(loading: false);
  }
}
