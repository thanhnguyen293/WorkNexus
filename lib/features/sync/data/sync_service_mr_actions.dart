part of 'sync_service.dart';

/// GitLab merge request / issue and GitHub pull request / issue actions
/// ([GitLabMrService], [GitHubPrService]).
mixin _MergeRequestActions on _SyncCore {
  // ---- GitLab actions (close / reopen / merge / approve) ----

  /// Closes a GitLab issue or MR, then refreshes its cached detail/status.
  @override
  Future<Result<void>> closeGitLabItem(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'closed',
    );
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
    return _gitlabAction(
      ticket,
      optimistic,
      (a) => isMr ? a.closeMergeRequest(ticket) : a.closeIssue(ticket),
    );
  }

  /// Reopens a GitLab issue or MR, then refreshes its cached detail/status.
  @override
  Future<Result<void>> reopenGitLabItem(Ticket ticket) {
    final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
    final optimistic = ticket.copyWith(
      status: isMr ? UnifiedStatus.review : UnifiedStatus.todo,
      providerStatus: 'opened',
    );
    return _gitlabAction(
      ticket,
      optimistic,
      (a) => isMr ? a.reopenMergeRequest(ticket) : a.reopenIssue(ticket),
    );
  }

  /// Merges a GitLab merge request, then refreshes its cached detail/status.
  @override
  Future<Result<void>> mergeGitLabMr(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'merged',
    );
    return _gitlabAction(
      ticket,
      optimistic,
      (a) => a.mergeMergeRequest(ticket),
    );
  }

  /// Approves a GitLab merge request, then refreshes its cached detail.
  @override
  Future<Result<void>> approveGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.approveMergeRequest(ticket));

  /// Rebases a GitLab MR onto its target, then refreshes its cached detail. No
  /// status change — only the merge status flips, which the refresh picks up.
  @override
  Future<Result<void>> rebaseGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.rebaseMergeRequest(ticket));

  // ---- GitHub actions (close / reopen / merge) ----

  /// Closes a GitHub issue or PR, then refreshes its cached detail/status.
  @override
  Future<Result<void>> closeGitHubItem(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'closed',
    );
    return _githubAction(ticket, optimistic, (a) => a.closeItem(ticket));
  }

  /// Reopens a GitHub issue or PR, then refreshes its cached detail/status.
  @override
  Future<Result<void>> reopenGitHubItem(Ticket ticket) {
    final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';
    final optimistic = ticket.copyWith(
      status: isPr ? UnifiedStatus.review : UnifiedStatus.todo,
      providerStatus: 'open',
    );
    return _githubAction(ticket, optimistic, (a) => a.reopenItem(ticket));
  }

  /// Merges a GitHub pull request, then refreshes its cached detail/status.
  @override
  Future<Result<void>> mergeGitHubPr(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'merged',
    );
    return _githubAction(ticket, optimistic, (a) => a.mergePull(ticket));
  }

  /// Updates a GitHub PR's branch with its base ("Update branch"), then refreshes
  /// its cached detail. No status change — only the mergeable state flips.
  @override
  Future<Result<void>> updateGitHubPrBranch(Ticket ticket) =>
      _githubAction(ticket, ticket, (a) => a.updateBranch(ticket));
}
