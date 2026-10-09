part of 'sync_service.dart';

/// Provider-agnostic ticket actions (assign, comment, reviewers, GitLab
/// labels/milestone/time) and ZenTao bug workflow actions ([ZenTaoBugService]).
mixin _TicketActions on _SyncCore {
  /// Users the ticket can be assigned to (empty when unavailable). GitLab/GitHub
  /// have no account-wide assignable list, so members are fetched per-project/repo.
  @override
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) return const Ok(<ProviderUser>[]);
    if (adapter is GitLabMrAdapter) return adapter.listProjectMembers(ticket);
    if (adapter is GitHubAdapter) return adapter.listRepoAssignees(ticket);
    return adapter.listUsers();
  }

  /// Posts [body] as a comment on [ticket] via its provider, then refreshes the
  /// thread from the provider so the canonical comment (with the real author and
  /// timestamp) lands in drift, from where the panel reads reactively. Returns
  /// the failure if the account lacks credentials or the provider rejects it.
  @override
  Future<Result<void>> postComment(Ticket ticket, String body) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.postComment(ticket, body);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return syncTicketDetail(ticket);
    }
  }

  /// Reassigns the ticket, then refreshes its cached detail/status/history.
  @override
  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.assignTicket(
      ticket,
      assignee: assignee,
      comment: comment,
    );
    if (res case Err(:final failure)) return Err(failure);
    return syncTicketDetail(ticket);
  }

  /// Sets/requests reviewers on a GitLab MR or GitHub PR, then refreshes detail.
  /// GitLab replaces the reviewer set; GitHub requests the given logins.
  @override
  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final Result<bool> res;
    if (adapter is GitLabMrAdapter) {
      res = await adapter.setReviewers(ticket, logins);
    } else if (adapter is GitHubAdapter) {
      res = await adapter.setReviewers(ticket, logins);
    } else {
      return const Err(UnexpectedFailure('Reviewers are GitLab/GitHub only'));
    }
    if (res case Err(:final failure)) return Err(failure);
    return syncTicketDetail(ticket);
  }

  @override
  Future<Result<List<ProviderLabelOption>>> listGitLabLabels(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listProjectLabels(ticket);
  }

  @override
  Future<Result<void>> setGitLabLabels(Ticket ticket, List<String> labels) =>
      _gitlabAction(ticket, ticket, (a) => a.setLabels(ticket, labels));

  @override
  Future<Result<List<ProviderMilestoneOption>>> listGitLabMilestones(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listProjectMilestones(ticket);
  }

  @override
  Future<Result<void>> setGitLabMilestone(Ticket ticket, int? milestoneId) =>
      _gitlabAction(ticket, ticket, (a) => a.setMilestone(ticket, milestoneId));

  @override
  Future<Result<void>> updateGitLabTimeTracking(
    Ticket ticket, {
    String? estimate,
    String? spent,
    bool resetEstimate = false,
    bool resetSpent = false,
  }) => _gitlabAction(
    ticket,
    ticket,
    (a) => a.updateTimeTracking(
      ticket,
      estimate: estimate,
      spent: spent,
      resetEstimate: resetEstimate,
      resetSpent: resetSpent,
    ),
  );

  /// Resolves a bug, then refreshes its cached detail/status/history.
  @override
  Future<Result<void>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? build,
    String? assignee,
    String? comment,
  }) async {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.review,
      providerStatus: 'resolved',
      labels: _withResolution(ticket.labels, resolution),
    );
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      await _rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.resolveBug(
      ticket,
      resolution: resolution,
      resolvedBuild: build,
      assignee: assignee,
      comment: comment,
    );
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    // Trust the server's post-action state (assignee, status, resolution) from
    // the detail refresh — do NOT re-apply the optimistic here, or it clobbers
    // the real assignee (resolve → reporter) and masks a failed activate.
    return syncTicketDetail(ticket);
  }

  /// Activates/reopens a bug, then refreshes its cached detail/status/history.
  @override
  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
    UnifiedStatus optimisticStatus = UnifiedStatus.todo,
  }) async {
    final optimistic = ticket.copyWith(
      status: optimisticStatus,
      providerStatus: 'active',
      labels: _withoutResolution(ticket.labels),
    );
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      await _rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.activateBug(
      ticket,
      openedBuild: build,
      assignee: assignee,
      comment: comment,
    );
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    // Trust the server's post-action state (assignee, status, resolution) from
    // the detail refresh — do NOT re-apply the optimistic here, or it clobbers
    // the real assignee (resolve → reporter) and masks a failed activate.
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

  /// Confirms a New/Unconfirmed bug (ZenTao `confirmed = 1`), then refreshes its
  /// cached detail/status. The bug stays `active`, moving from New/Unconfirmed
  /// into Confirmed/To Fix.
  @override
  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.todo,
      providerStatus: 'active',
    );
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      await _rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.confirmBug(
      ticket,
      assignee: assignee,
      comment: comment,
    );
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    // Trust the server's post-action state from the detail refresh rather than
    // re-applying the optimistic (which would mask a failed confirm).
    await syncTicketDetail(ticket);
    return const Ok(null);
  }
}
