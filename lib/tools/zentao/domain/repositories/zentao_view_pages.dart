import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/cancel_signal.dart';

/// Pages of a ZenTao server-side ticket view, stored locally as they arrive:
/// each page's tickets are written to the local database (the board reads them
/// from there) and the page tells which tickets the view holds and whether
/// more follow.
abstract interface class ZenTaoViewPages {
  /// One [page] of product [productId]'s bug view [browseType] (`unconfirmed`,
  /// `toclosed`, …), [limit] bugs per page, in [sort] order.
  Future<Result<ViewPage>> syncProductBugsPage({
    required String accountId,
    required String productId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  });

  /// One [page] of execution [executionId]'s task status view [browseType]
  /// (`wait`, `doing`, …), [limit] tasks per page, in [sort] order.
  Future<Result<ViewPage>> syncExecutionTasksPage({
    required String accountId,
    required String executionId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  });
}
