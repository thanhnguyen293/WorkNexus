import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';

class MergeGitLabMr {
  const MergeGitLabMr(this._service);

  final GitLabMrService _service;

  Future<Result<void>> call(Ticket ticket) => _service.mergeGitLabMr(ticket);
}
