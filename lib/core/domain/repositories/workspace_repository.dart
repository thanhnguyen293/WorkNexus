import '../entities/account.dart';
import '../entities/project.dart';
import '../entities/workspace.dart';

/// Reactive reads for the sidebar Sources tree (workspaces → accounts → projects).
abstract class WorkspaceRepository {
  Stream<List<Workspace>> watchWorkspaces();
  Stream<List<Account>> watchAccounts();
  Stream<List<Project>> watchProjects();
}
