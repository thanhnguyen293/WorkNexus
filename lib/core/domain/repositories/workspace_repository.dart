import '../entities/account.dart';
import '../entities/project.dart';
import '../entities/workspace.dart';

/// Reactive reads and mutations for workspaces, accounts and projects.
abstract class WorkspaceRepository {
  Stream<List<Workspace>> watchWorkspaces();
  Stream<List<Account>> watchAccounts();
  Stream<List<Project>> watchProjects();
  Future<void> createWorkspace(Workspace workspace);
  Future<void> updateWorkspace(Workspace workspace);
}
