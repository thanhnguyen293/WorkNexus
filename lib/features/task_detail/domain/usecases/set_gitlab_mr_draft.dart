import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';

/// Marks a merge request as a draft, or as ready for review.
class SetGitLabMrDraft {
  const SetGitLabMrDraft(this._service);

  final GitLabMrService _service;

  Future<Result<void>> call(Ticket ticket, {required bool draft}) =>
      _service.setGitLabMrDraft(ticket, draft: draft);
}
