part of 'gitlab_adapter.dart';

/// Workflow actions: assignment, the ZenTao-only bug transitions (unsupported
/// here), issue/MR close/reopen via `state_event`, and MR merge/approve/rebase.
mixin _GitLabActions on _GitLabAdapterBase {
  @override
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    // Resolve the assignee login → numeric id (what `assignee_ids` expects).
    final userRes = await _guard(() => _client.userByUsername(assignee));
    switch (userRes) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final id = value?.id;
        if (id == null) {
          return Err(NotFoundFailure('No GitLab user "$assignee"'));
        }
        return _guard(() async {
          final ref = _projectRef(ticket);
          if (_kindOf(ticket) == GitLabKind.issue) {
            await _client.updateIssue(
              ref,
              ticket.externalKey,
              assigneeIds: [id],
            );
          } else {
            await _client.updateMergeRequest(
              ref,
              ticket.externalKey,
              assigneeIds: [id],
            );
          }
          if (comment != null && comment.trim().isNotEmpty) {
            _kindOf(ticket) == GitLabKind.issue
                ? await _client.postIssueNote(ref, ticket.externalKey, comment)
                : await _client.postMrNote(ref, ticket.externalKey, comment);
          }
          return true;
        });
    }
  }

  @override
  Future<Result<bool>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? resolvedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('resolveBug is ZenTao-only; GitLab uses close/reopen'),
  );

  @override
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('activateBug is ZenTao-only; GitLab uses close/reopen'),
  );

  @override
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('confirmBug is ZenTao-only; GitLab has no bug workflow'),
  );

  /// Close / reopen an issue via `state_event` on the issue update endpoint.
  @override
  Future<Result<bool>> closeIssue(Ticket ticket) =>
      _issueStateEvent(ticket, 'close');
  @override
  Future<Result<bool>> reopenIssue(Ticket ticket) =>
      _issueStateEvent(ticket, 'reopen');

  /// Close / reopen a merge request via `state_event`.
  @override
  Future<Result<bool>> closeMergeRequest(Ticket ticket) =>
      _mrStateEvent(ticket, 'close');
  @override
  Future<Result<bool>> reopenMergeRequest(Ticket ticket) =>
      _mrStateEvent(ticket, 'reopen');

  /// Merge a merge request.
  @override
  Future<Result<bool>> mergeMergeRequest(Ticket ticket) => _guard(() async {
    await _client.mergeMergeRequest(_projectRef(ticket), ticket.externalKey);
    return true;
  });

  /// Approve a merge request as the authenticated user.
  @override
  Future<Result<bool>> approveMergeRequest(Ticket ticket) => _guard(() async {
    await _client.approveMergeRequest(_projectRef(ticket), ticket.externalKey);
    return true;
  });

  /// Rebase a merge request onto its target branch (resolves a `need_rebase`
  /// detailed merge status).
  @override
  Future<Result<bool>> rebaseMergeRequest(Ticket ticket) => _guard(() async {
    await _client.rebaseMergeRequest(_projectRef(ticket), ticket.externalKey);
    return true;
  });

  Future<Result<bool>> _issueStateEvent(Ticket ticket, String event) =>
      _guard(() async {
        await _client.updateIssue(
          _projectRef(ticket),
          ticket.externalKey,
          stateEvent: event,
        );
        return true;
      });

  Future<Result<bool>> _mrStateEvent(Ticket ticket, String event) =>
      _guard(() async {
        await _client.updateMergeRequest(
          _projectRef(ticket),
          ticket.externalKey,
          stateEvent: event,
        );
        return true;
      });
}
