import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/workspace.dart';
import '../../../data/local/mappers.dart';
import '../domain/repositories/connection_repository.dart';

class LocalConnectionRepository implements ConnectionRepository {
  LocalConnectionRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> addAccount(Account account) async {
    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(accountToCompanion(account));
  }

  @override
  Future<void> addWorkspace(Workspace workspace) async {
    final count = (await _db.select(_db.workspaces).get()).length;
    await _db
        .into(_db.workspaces)
        .insertOnConflictUpdate(workspaceToCompanion(workspace, count));
  }

  @override
  Future<void> removeAccount(String id) async {
    await _db.transaction(() async {
      // Remove the account's projects, tickets, and the account itself.
      final projectIds = await (_db.select(
        _db.projects,
      )..where((p) => p.accountId.equals(id))).map((p) => p.id).get();
      await (_db.delete(
        _db.tickets,
      )..where((t) => t.accountId.equals(id))).go();
      for (final pid in projectIds) {
        await (_db.delete(
          _db.comments,
        )..where((c) => c.ticketId.like('$pid%'))).go();
      }
      await (_db.delete(
        _db.projects,
      )..where((p) => p.accountId.equals(id))).go();
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
    });
  }
}
