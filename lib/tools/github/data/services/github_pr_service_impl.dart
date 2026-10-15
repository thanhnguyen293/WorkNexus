import 'dart:typed_data';

import '../../../../core/data/mappers/mappers.dart';
import '../../../../core/domain/adapters/github_pr_adapter.dart';
import '../../../../core/domain/adapters/github_pr_service.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/repo_change.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/synthetic_labels.dart';
import '../../../../shared/sync/data/sync_coordinator.dart';

class GitHubPrServiceImpl implements GitHubPrService {
  const GitHubPrServiceImpl(this._coordinator);

  final SyncCoordinator _coordinator;

  @override
  Future<Result<void>> postComment(Ticket ticket, String body) =>
      _coordinator.postComment(ticket, body);

  @override
  Future<Result<void>> closeGitHubItem(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'closed',
    );
    return _githubAction(ticket, optimistic, (a) => a.closeItem(ticket));
  }

  @override
  Future<Result<void>> reopenGitHubItem(Ticket ticket) {
    final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';
    final optimistic = ticket.copyWith(
      status: isPr ? UnifiedStatus.review : UnifiedStatus.todo,
      providerStatus: 'open',
    );
    return _githubAction(ticket, optimistic, (a) => a.reopenItem(ticket));
  }

  @override
  Future<Result<void>> mergeGitHubPr(Ticket ticket) {
    final optimistic = ticket.copyWith(
      status: UnifiedStatus.done,
      providerStatus: 'merged',
    );
    return _githubAction(ticket, optimistic, (a) => a.mergePull(ticket));
  }

  @override
  Future<Result<void>> updateGitHubPrBranch(Ticket ticket) =>
      _githubAction(ticket, ticket, (a) => a.updateBranch(ticket));

  @override
  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins) =>
      _coordinator.setReviewers(ticket, logins);

  @override
  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) => _coordinator.assignTicket(ticket, assignee: assignee, comment: comment);

  @override
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) =>
      _coordinator.listUsers(ticket);

  @override
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) =>
      _coordinator.fetchTicketImage(ticket, url);

  @override
  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket) async {
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitHubPrAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket) async {
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitHubPrAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullFiles(ticket);
  }

  @override
  Future<Result<List<String>>> syncGitHubRepoItems({
    required String accountId,
    required String repoId,
    required bool pullRequests,
  }) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! GitHubPrAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listRepoItems(repoId, pullRequests: pullRequests);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = githubRepoLabel(repoId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _coordinator.upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  @override
  Future<Result<List<String>>> syncGitHubMine(String accountId) async {
    final db = _coordinator.db;
    final accountRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _coordinator.adapterFor(accountId);
    if (adapter is! GitHubPrAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listMyPullRequests();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = githubMineLabel(accountId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _coordinator.upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  @override
  Future<Result<List<ProviderProject>>> listProjects(String accountId) =>
      _coordinator.listProjects(accountId);

  @override
  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _coordinator.cachedProjects(accountId);

  Future<Result<void>> _githubAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(GitHubPrAdapter adapter) action,
  ) async {
    await _coordinator.optimisticallyUpdateTicket(optimistic);
    final adapter = await _coordinator.adapterFor(ticket.accountId);
    if (adapter is! GitHubPrAdapter) {
      await _coordinator.rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await action(adapter);
    if (res case Err(:final failure)) {
      await _coordinator.rollbackTicket(ticket);
      return Err(failure);
    }
    await _coordinator.syncTicketDetail(ticket);
    return const Ok(null);
  }
}
