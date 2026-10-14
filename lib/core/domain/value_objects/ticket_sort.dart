import 'package:freezed_annotation/freezed_annotation.dart';

part 'ticket_sort.freezed.dart';

/// What a ticket table can be ordered by — the sortable columns of ZenTao's own
/// task and bug lists.
enum TicketSortField {
  id,
  title,
  priority,
  severity,
  status,
  assignee,
  estimate,
  left,
  resolution,
  updated;

  /// Whether a first click orders this field highest/newest first, as ZenTao
  /// does for ids and dates; the rest start ascending.
  bool get startsDescending => this == id || this == updated;
}

/// The order a ticket table asks its provider for. The provider sorts each
/// page, so a table that loads more pages keeps one continuous order.
@freezed
abstract class TicketSort with _$TicketSort {
  const TicketSort._();

  const factory TicketSort(
    TicketSortField field, {
    @Default(false) bool descending,
  }) = _TicketSort;

  /// Newest first: the order the boards load in.
  static const newest = TicketSort(TicketSortField.id, descending: true);

  /// What clicking [column]'s header turns this order into: the same column
  /// flips direction, another column starts in its own default direction.
  TicketSort toggled(TicketSortField column) => column == field
      ? copyWith(descending: !descending)
      : TicketSort(column, descending: column.startsDescending);
}
