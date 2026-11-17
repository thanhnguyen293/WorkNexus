import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../domain/usecases/compare_tickets.dart';

/// The order of the cards in each Kanban column, picked from the board
/// toolbar. Kept for the session, shared by every board.
class BoardSortController extends Notifier<TicketSort> {
  @override
  TicketSort build() => boardDefaultSort;

  /// Picking the current field flips its direction; another field starts in
  /// its own default direction.
  void sortBy(TicketSortField field) => state = state.toggled(field);
}

final boardSortProvider = NotifierProvider<BoardSortController, TicketSort>(
  BoardSortController.new,
);
