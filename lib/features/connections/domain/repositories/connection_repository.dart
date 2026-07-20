import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/workspace.dart';

/// Persists provider connections (accounts) and workspaces. Secrets are handled
/// separately by the credential store; only the account metadata (incl.
/// credentialsRef) lives here.
abstract class ConnectionRepository {
  Future<void> addAccount(Account account);
  Future<void> removeAccount(String id);

  /// Create (or update) a workspace, e.g. when connecting into a new one.
  Future<void> addWorkspace(Workspace workspace);
  Future<void> updateWorkspace(Workspace workspace);
  Future<List<String>> deleteWorkspace(String id);
}
