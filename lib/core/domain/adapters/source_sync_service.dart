import '../../error/result.dart';
import '../entities/account.dart';
import 'provider_adapter.dart';

/// Pulls provider data into the local database for the board, the sidebar and
/// the connections screen: whole accounts, the source lists, and the ticket
/// slice behind each source. Implemented in the data layer.
abstract interface class SourceSyncService {
  /// Syncs [account]'s assigned tickets; returns how many were stored.
  Future<Result<int>> syncAccount(Account account);

  /// ZenTao products (the sidebar's Bugs group).
  Future<Result<List<ProviderProduct>>> listProducts(String accountId);

  /// ZenTao projects, GitLab projects or GitHub repositories of [accountId].
  Future<Result<List<ProviderProject>>> listProjects(String accountId);

  /// The executions (sprints) of a ZenTao project.
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  );

  /// Syncs one ZenTao product bug-board tab; returns its ticket ids in order.
  Future<Result<List<String>>> syncProductBugsTab({
    required String accountId,
    required String productId,
    required String browseType,
  });

  /// Drops the cached slice so the next [syncProductBugsTab] hits the server.
  void invalidateProductBugsTab({
    required String accountId,
    required String productId,
    required String browseType,
  });

  /// Syncs a ZenTao execution's tasks; returns how many were stored.
  Future<Result<int>> syncExecutionTasks(ProviderExecution execution);

  /// Drops the cached slice so the next [syncExecutionTasks] hits the server.
  void invalidateExecutionTasks({
    required String accountId,
    required String executionId,
  });

  /// Syncs a GitLab project's merge requests or issues; returns their ids.
  Future<Result<List<String>>> syncGitLabProjectItems({
    required String accountId,
    required String projectId,
    required bool mergeRequests,
  });

  /// Syncs the merge requests involving the GitLab user; returns their ids.
  Future<Result<List<String>>> syncGitLabMine(String accountId);

  /// Syncs a GitHub repository's pull requests or issues; returns their ids.
  Future<Result<List<String>>> syncGitHubRepoItems({
    required String accountId,
    required String repoId,
    required bool pullRequests,
  });

  /// Syncs the pull requests involving the GitHub user; returns their ids.
  Future<Result<List<String>>> syncGitHubMine(String accountId);

  /// The GitLab instance version (e.g. `16.3.8`), or null when unknown.
  Future<String?> gitlabServerVersion(String accountId);
}
