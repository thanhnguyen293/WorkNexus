import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/repo_change.dart';
import 'provider_adapter.dart';

abstract interface class GitHubPrAdapter implements ProviderAdapter {
  Future<Result<bool>> closeItem(Ticket ticket);

  Future<Result<bool>> reopenItem(Ticket ticket);

  Future<Result<bool>> mergePull(Ticket ticket);

  Future<Result<bool>> updateBranch(Ticket ticket);

  Future<Result<List<Ticket>>> listRepoItems(
    String repoId, {
    required bool pullRequests,
  });

  Future<Result<List<Ticket>>> listMyPullRequests();

  Future<Result<List<ProviderUser>>> listRepoAssignees(Ticket ticket);

  Future<Result<bool>> setReviewers(Ticket ticket, List<String> logins);

  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket);

  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket);
}
