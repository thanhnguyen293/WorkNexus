import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to the kept bug / task drafts ([TicketDrafts]).
class TicketDraftLocalDatasource {
  const TicketDraftLocalDatasource(this._db);

  final AppDatabase _db;

  Stream<List<TicketDraftRow>> watchAll() => (_db.select(
    _db.ticketDrafts,
  )..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])).watch();

  Future<TicketDraftRow?> read(String id) => (_db.select(
    _db.ticketDrafts,
  )..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<void> save(TicketDraftsCompanion row) =>
      _db.into(_db.ticketDrafts).insertOnConflictUpdate(row);

  Future<void> delete(String id) =>
      (_db.delete(_db.ticketDrafts)..where((d) => d.id.equals(id))).go();
}
