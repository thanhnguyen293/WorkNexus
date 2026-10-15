import 'dart:typed_data';

import '../../../../core/data/mappers/mappers.dart';
import '../../../../core/domain/adapters/gitlab_mr_adapter.dart';
import '../../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/synthetic_labels.dart';
import '../../../../shared/sync/data/sync_coordinator.dart';

class GitLabMrServiceImpl implements GitLabMrService {
  const GitLabMrServiceImpl(this._coordinator);

  final SyncCoordinator _coordinator;

  @override
  Future<Result<void>> postComment(Ticket ticket, String body) =>
      _coordinator.postComment(ticket, body);

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

  @override
  Future<Result<void>> mergeGitLabMr(
    Ticket ticket, {
    bool? squash,
    bool? removeSourceBranch,
  }) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'merged',
    );
    return _gitlabAction(
      ticket,
      optimistic,
      (a) => a.mergeMergeRequest(
        ticket,
        squash: squash,
        removeSourceBranch: removeSourceBranch,
      ),
    );
  }

  @override
  Future<Result<void>> approveGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.approveMergeRequest(ticket));

  @override
  Future<Result<void>> unapproveGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.unapproveMergeRequest(ticket));

  @override
  Future<Result<void>> setGitLabMrDraft(Ticket ticket, {required bool draft}) {
    final optimistic = ticket.copyWith(
      status: draft ? UnifiedStatus.inprogress : UnifiedStatus.review,
      providerStatus: draft ? 'draft' : 'opened',
    );
    return _gitlabAction(
      ticket,
      optimistic,
      (a) => a.setMergeRequestDraft(ticket, draft: draft),
    );
  }

  @override
  Future<Result<void>> rebaseGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.rebaseMergeRequest(ticket));

  @override
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) =>
      _coordinator.listUsers(ticket);

  @override
  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) => _coordinator.assignTicket(ticket, assignee: assignee, comment: comment);

  @override
  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins) =>
      _coordinator.setReviewers(ticket, logins);

  @override
  Future<Result<List<ProviderLabelOption>>> listGitLabLabels(
    Ticket ticket,
  ) async {
    final adapter = await _coordinator.adapterFor(ticket.accountId);
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
    final adapter = await _coordinator.adapterFor(ticket.accountId);
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

  @override
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) =>
      _coordinator.fetchTicketImage(ticket, url);

  @override
  Future<Result<List<RepoCommit>>> listMergeRequestCommits(
    Ticket ticket,
  ) async {
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(
    Ticket ticket,
  ) async {
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestChanges(ticket);
  }

  @override
  Future<Result<List<String>>> syncGitLabProjectItems({
    required String accountId,
    required String projectId,
    required bool mergeRequests,
  }) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProjectItems(
      projectId,
      mergeRequests: mergeRequests,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = gitlabProjectLabel(projectId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _coordinator.upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  @override
  Future<Result<List<String>>> syncGitLabMine(String accountId) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! GitLabMrAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listMyMergeRequests();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = gitlabMineLabel(accountId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _coordinator.upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  @override
  Future<String?> gitlabServerVersion(String accountId) async {
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is GitLabMrAdapter) return adapter.serverVersion();
    return null;
  }

  @override
  Future<Result<List<ProviderProject>>> listProjects(String accountId) =>
      _coordinator.listProjects(accountId);

  @override
  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _coordinator.cachedProjects(accountId);

  Future<Result<void>> _gitlabAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(GitLabMrAdapter adapter) action,
  ) async {
    await _coordinator.optimisticallyUpdateTicket(optimistic);
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      await _coordinator.rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await action(adapter);
    if (res case Err(:final failure)) {
      await _coordinator.rollbackTicket(ticket);
      return Err(failure);
    }
    return _coordinator.syncTicketDetail(ticket);
  }
}
