import 'package:collection/collection.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/workspace.dart';
import '../../../core/domain/repositories/workspace_repository.dart';
import '../mappers.dart';

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
}
