import '../../../../core/domain/adapters/github_pr_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';

class CloseGitHubItem {
  const CloseGitHubItem(this._service);

  final GitHubPrService _service;

  Future<Result<void>> call(Ticket ticket) => _service.closeGitHubItem(ticket);
}
