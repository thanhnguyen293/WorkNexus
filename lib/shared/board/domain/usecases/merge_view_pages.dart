import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';

/// The same page of several server views as one page of one view (the
/// ZenTao bug board's "Related to me": assigned to, opened by and resolved by
/// me). A ticket in more than one of them is listed once, where it first
/// appears; there are more pages while any view has more. [ViewPage.total]
/// adds the views' totals, so it counts such a ticket more than once.
///
/// One view failing fails the page: its retry fetches them all again, and a
/// page fetched twice is stored the same way.
class MergeViewPages extends UseCase<Result<ViewPage>, List<Result<ViewPage>>> {
  const MergeViewPages();

  @override
  Result<ViewPage> call(List<Result<ViewPage>> pages) {
    final tickets = <String, Ticket>{};
    var total = 0;
    var hasMore = false;
    for (final page in pages) {
      switch (page) {
        case Err():
          return page;
        case Ok(:final value):
          for (final t in value.tickets) {
            tickets.putIfAbsent(t.id, () => t);
          }
          total += value.total;
          hasMore = hasMore || value.hasMore;
      }
    }
    return Ok(
      ViewPage(tickets: [...tickets.values], total: total, hasMore: hasMore),
    );
  }
}
