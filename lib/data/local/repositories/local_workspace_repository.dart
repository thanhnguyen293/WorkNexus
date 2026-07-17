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

  @override
  Stream<List<Account>> watchAccounts() =>
      _db.watchAccounts().map((rows) => rows.map(accountFromRow).toList());

  @override
  Stream<List<Project>> watchProjects() =>
      _db.watchProjects().map((rows) => rows.map(projectFromRow).toList());
}
