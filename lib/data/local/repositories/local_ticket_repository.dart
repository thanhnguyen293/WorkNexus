import 'package:collection/collection.dart';
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

  /// The rows of the last emission with their decoded tickets, by id. Drift
  /// re-runs the whole-table watch on every write, and decoding a row means
  /// two JSON decodes (labels, provider entity); a row that reads the same
  /// (rows compare by value) keeps its ticket instead, so an emission costs
  /// what changed, not the size of the table. Written by whichever
  /// subscription emits — the app has one (`ticketsProvider`); a second would
  /// still be correct, only hit less.
  var _decoded = <String, (TicketRow, Ticket)>{};

  /// Drift re-runs the query on every write to the table, changed or not;
  /// `distinct` keeps an unchanged set from re-rendering every consumer.
  @override
  Stream<List<Ticket>> watchTickets() => _db
      .watchTickets()
      .map(_tickets)
      .distinct(const ListEquality<Ticket>().equals);

  List<Ticket> _tickets(List<TicketRow> rows) {
    final next = <String, (TicketRow, Ticket)>{};
    final tickets = <Ticket>[];
    for (final row in rows) {
      final ticket = switch (_decoded[row.id]) {
        (final prior, final ticket) when prior == row => ticket,
        _ => ticketFromRow(row),
      };
      next[row.id] = (row, ticket);
      tickets.add(ticket);
    }
    _decoded = next;
    return tickets;
  }

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
