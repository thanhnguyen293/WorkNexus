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
  Future<void> updateWorkspace(Workspace workspace) async {
    final row = await (_db.select(
      _db.workspaces,
    )..where((w) => w.id.equals(workspace.id))).getSingleOrNull();
    await _db
        .into(_db.workspaces)
        .insertOnConflictUpdate(
          workspaceToCompanion(workspace, row?.sortOrder ?? 0),
        );
  }

  @override
  Future<List<String>> deleteWorkspace(String id) async {
    final credentials = <String>[];
    await _db.transaction(() async {
      final accounts = await (_db.select(
        _db.accounts,
      )..where((a) => a.workspaceId.equals(id))).get();
      final accountIds = accounts.map((a) => a.id).toList();
      credentials.addAll(
        accounts.map((a) => a.credentialsRef).whereType<String>(),
      );
      if (accountIds.isNotEmpty) {
        final ticketIds = await (_db.select(
          _db.tickets,
        )..where((t) => t.accountId.isIn(accountIds))).map((t) => t.id).get();
        if (ticketIds.isNotEmpty) {
          await (_db.delete(
            _db.comments,
          )..where((c) => c.ticketId.isIn(ticketIds))).go();
          await (_db.delete(
            _db.activities,
          )..where((a) => a.ticketId.isIn(ticketIds))).go();
          await (_db.delete(
            _db.translations,
          )..where((t) => t.ticketId.isIn(ticketIds))).go();
        }
        await (_db.delete(
          _db.tickets,
        )..where((t) => t.accountId.isIn(accountIds))).go();
        await (_db.delete(
          _db.projects,
        )..where((p) => p.accountId.isIn(accountIds))).go();
        await (_db.delete(
          _db.accounts,
        )..where((a) => a.id.isIn(accountIds))).go();
      }
      await (_db.delete(_db.workspaces)..where((w) => w.id.equals(id))).go();
    });
    return credentials;
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
