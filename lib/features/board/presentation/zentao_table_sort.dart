import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/value_objects/ticket_sort.dart';
import '../../../core/settings/app_settings.dart';

/// The column a ZenTao ticket table is sorted by, toggled from its headers.
/// Kept for the session, apart for tasks and bugs (their columns differ).
class ZenTaoTableSortController extends Notifier<TicketSort> {
  @override
  TicketSort build() => TicketSort.newest;

  void sortBy(TicketSortField field) => state = state.toggled(field);
}

final zentaoTaskTableSortProvider =
    NotifierProvider<ZenTaoTableSortController, TicketSort>(
      ZenTaoTableSortController.new,
    );

final zentaoBugTableSortProvider =
    NotifierProvider<ZenTaoTableSortController, TicketSort>(
      ZenTaoTableSortController.new,
    );

/// The order a board's views are fetched in: the table's sort while the boards
/// show as a table, else newest first. Sorting by status orders the views, not
/// the tickets within one, so each view is still fetched newest first.
TicketSort _fetchSort(
  Ref ref,
  NotifierProvider<ZenTaoTableSortController, TicketSort> sort,
) {
  final table =
      ref.watch(appSettingsProvider.select((s) => s.boardLayout)) ==
      BoardLayout.table;
  final chosen = table ? ref.watch(sort) : TicketSort.newest;
  return chosen.field == TicketSortField.status ? TicketSort.newest : chosen;
}

final zentaoTaskFetchSortProvider = Provider<TicketSort>(
  (ref) => _fetchSort(ref, zentaoTaskTableSortProvider),
);

final zentaoBugFetchSortProvider = Provider<TicketSort>(
  (ref) => _fetchSort(ref, zentaoBugTableSortProvider),
);
