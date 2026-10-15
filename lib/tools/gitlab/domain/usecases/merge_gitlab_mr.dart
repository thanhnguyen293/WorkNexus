import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';

class MergeGitLabMr {
  const MergeGitLabMr(this._service);

  final GitLabMrService _service;

  /// Merges [ticket]; a null option keeps the MR's own setting.
  Future<Result<void>> call(
    Ticket ticket, {
    bool? squash,
    bool? removeSourceBranch,
  }) => _service.mergeGitLabMr(
    ticket,
    squash: squash,
    removeSourceBranch: removeSourceBranch,
  );
}
