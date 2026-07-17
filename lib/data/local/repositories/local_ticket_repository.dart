import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/repositories/ticket_repository.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../mappers.dart';

/// Drift-backed [TicketRepository] — the local read model for tickets.
class LocalTicketRepository implements TicketRepository {
  LocalTicketRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Ticket>> watchTickets() =>
      _db.watchTickets().map((rows) => rows.map(ticketFromRow).toList());

  @override
  Future<Ticket?> getTicket(String id) async {
    final row = await (_db.select(
      _db.tickets,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : ticketFromRow(row);
  }

  @override
  Future<void> upsertTickets(List<Ticket> tickets) async {
    if (tickets.isEmpty) return;
    await _db.batch((b) {
      for (final t in tickets) {
        b.insert(
          _db.tickets,
          ticketToCompanion(t),
          onConflict: DoUpdate((_) => ticketToCompanion(t)),
        );
      }
    });
  }

  @override
  Future<void> moveTicket(String id, UnifiedStatus status) async {
    await (_db.update(_db.tickets)..where((t) => t.id.equals(id))).write(
      TicketsCompanion(
        statusNorm: Value(status.name),
        providerStatus: Value(status.name),
      ),
    );
  }
}
