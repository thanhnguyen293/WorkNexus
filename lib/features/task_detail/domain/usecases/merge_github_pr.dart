import '../../../../core/domain/adapters/github_pr_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';

class MergeGitHubPr {
  const MergeGitHubPr(this._service);

  final GitHubPrService _service;

  Future<Result<void>> call(Ticket ticket) => _service.mergeGitHubPr(ticket);
}
