import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';

/// One Kanban column: a status and the tickets currently in it (already
/// filtered + ordered by the board use case).
class BoardColumn {
  const BoardColumn({required this.status, required this.tickets});

  final UnifiedStatus status;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

/// The full board: six columns in status order plus the total.
class BoardModel {
  const BoardModel({required this.columns});

  final List<BoardColumn> columns;

  int get total => columns.fold(0, (sum, c) => sum + c.tickets.length);

  static const empty = BoardModel(columns: []);
}
