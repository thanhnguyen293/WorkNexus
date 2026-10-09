part of 'github_adapter.dart';

/// Workflow actions: assignment, the ZenTao-only bug transitions (unsupported
/// here), issue/PR close/reopen via the issues `state` field, and PR merge /
/// update-branch.
mixin _GitHubActions on _GitHubAdapterBase {
  @override
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    // GitHub assigns by login string directly — no username→id lookup needed.
    return _guard(() async {
      final ref = _repoRef(ticket);
      await _client.updateIssue(ref, ticket.externalKey, assignees: [assignee]);
      if (comment != null && comment.trim().isNotEmpty) {
        await _client.postIssueComment(ref, ticket.externalKey, comment);
      }
      return true;
    });
  }

  @override
  Future<Result<bool>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? resolvedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('resolveBug is ZenTao-only; GitHub uses close/reopen'),
  );

  @override
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('activateBug is ZenTao-only; GitHub uses close/reopen'),
  );

  @override
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('confirmBug is ZenTao-only; GitHub has no bug workflow'),
  );

  /// Close / reopen an issue or PR via the issues `state` field (a PR is an
  /// issue, so this works for both).
  Future<Result<bool>> closeItem(Ticket ticket) => _setState(ticket, 'closed');
  Future<Result<bool>> reopenItem(Ticket ticket) => _setState(ticket, 'open');

  /// Merge a pull request.
  Future<Result<bool>> mergePull(Ticket ticket) => _guard(() async {
    await _client.mergePull(_repoRef(ticket), ticket.externalKey);
    return true;
  });

  /// Update a PR branch with its base ("Update branch"; resolves a `behind`
  /// mergeable state — GitHub has no true rebase via the API).
  Future<Result<bool>> updateBranch(Ticket ticket) => _guard(() async {
    await _client.updateBranch(_repoRef(ticket), ticket.externalKey);
    return true;
  });

  Future<Result<bool>> _setState(Ticket ticket, String state) =>
      _guard(() async {
        await _client.updateIssue(
          _repoRef(ticket),
          ticket.externalKey,
          state: state,
        );
        return true;
      });
}
