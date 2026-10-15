import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../mappers/mappers.dart';

/// Drift-backed [WorkspaceRepository] — workspaces, accounts and projects.
class LocalWorkspaceRepository implements WorkspaceRepository {
  LocalWorkspaceRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Workspace>> watchWorkspaces() =>
      _db.watchWorkspaces().map((rows) => rows.map(workspaceFromRow).toList());

  // Every synced page re-upserts its account and projects, and drift
  // re-emits on any write to a table, changed or not. Only a real change goes
  // out, or each page would rebuild everything watching them (the
  // notifications refetched once per page).
  @override
  Stream<List<Account>> watchAccounts() => _db
      .watchAccounts()
      .map((rows) => rows.map(accountFromRow).toList())
      .distinct(const ListEquality<Account>().equals);

  @override
  Stream<List<Project>> watchProjects() => _db
      .watchProjects()
      .map((rows) => rows.map(projectFromRow).toList())
      .distinct(const ListEquality<Project>().equals);

  @override
  Future<void> createWorkspace(Workspace workspace) async {
    final rows = await _db.select(_db.workspaces).get();
    await _db
        .into(_db.workspaces)
        .insert(
          workspaceToCompanion(workspace, rows.length),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> updateWorkspace(Workspace workspace) async {
    await (_db.update(
      _db.workspaces,
    )..where((w) => w.id.equals(workspace.id))).write(
      WorkspacesCompanion(
        name: Value(workspace.name),
        shortCode: Value(workspace.shortCode),
        colorValue: Value(workspace.colorValue),
        iconKey: Value(workspace.iconKey),
        isPersonal: Value(workspace.isPersonal),
      ),
    );
  }
}
