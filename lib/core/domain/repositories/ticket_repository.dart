import '../entities/ticket.dart';
import '../value_objects/unified_status.dart';

/// Reactive read model for tickets. Implementations back this with drift today
/// (`LocalTicketRepository`) or an HTTP sync source later (`RemoteTicketRepository`)
/// — the application/presentation layers never change.
abstract class TicketRepository {
  /// Emits the full ticket set, re-emitting whenever the underlying store changes.
  Stream<List<Ticket>> watchTickets();

  Future<Ticket?> getTicket(String id);

  /// Insert or update tickets (used by sync). No-op-safe on empty input.
  Future<void> upsertTickets(List<Ticket> tickets);

  /// Optimistically move a ticket to a new status (drag-and-drop / status change).
  Future<void> moveTicket(String id, UnifiedStatus status);
}
