import 'dart:io';

import '../../../core/domain/adapters/account_sync_service.dart';
import '../../../core/domain/adapters/github_pr_service.dart';
import '../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../core/domain/adapters/zentao_workflow_service.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/repositories/sync_status_repository.dart';
import '../../../core/domain/value_objects/account_sync_status.dart';
import '../../../core/domain/value_objects/repo_change.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import 'sync_coordinator.dart';

export 'merge_detail_labels.dart';

/// Legacy facade delegating to [SyncCoordinator] and tool services.
class SyncService extends SyncCoordinator
    implements
        GitLabMrService,
        GitHubPrService,
        ZenTaoTicketService,
        TicketDetailService,
        AccountSyncService {
  SyncService(
    super.db,
    super.credentials, {
    required super.registry,
    super.attachmentCache,
    ZenTaoTicketService? zentaoTicketService,
    GitLabMrService? gitlabMrService,
    GitHubPrService? githubPrService,
    ZenTaoWorkflowService? workflowService,
    SyncStatusRepository? statusRepository,
  }) : _zentao = zentaoTicketService,
       _gitlab = gitlabMrService,
       _github = githubPrService,
       _workflow = workflowService,
       _statusRepo = statusRepository;

  final ZenTaoTicketService? _zentao;
  final GitLabMrService? _gitlab;
  final GitHubPrService? _github;
  final ZenTaoWorkflowService? _workflow;
  final SyncStatusRepository? _statusRepo;

  Future<T> _track<T>(String accountId, Future<T> Function() action) async {
    _statusRepo?.report(accountId, const AccountSyncStatus.syncing());
    try {
      final result = await action();
      if (result is Result && result.isErr) {
        final failure = (result as Err).failure;
        final status = switch (failure) {
          AuthFailure() => const AccountSyncStatus.authExpired(),
          NetworkFailure() => const AccountSyncStatus.offline(),
          _ => AccountSyncStatus.error(failure.message),
        };
        _statusRepo?.report(accountId, status);
      } else {
        _statusRepo?.report(
          accountId,
          AccountSyncStatus.idle(lastSyncedAt: DateTime.now()),
        );
      }
      return result;
    } on SocketException {
      _statusRepo?.report(accountId, const AccountSyncStatus.offline());
      rethrow;
    } catch (e) {
      _statusRepo?.report(accountId, AccountSyncStatus.error(e.toString()));
      rethrow;
    }
  }

  @override
  Future<Result<int>> syncAccount(Account account) =>
      _track(account.id, () => super.syncAccount(account));

  @override
  Future<Result<int>> syncAccountById(String accountId) =>
      _track(accountId, () => super.syncAccountById(accountId));

  @override
  Future<Result<void>> syncTicketDetail(Ticket ticket) =>
      _track(ticket.accountId, () => super.syncTicketDetail(ticket));

  // ---- GitLab MR Service ----

  @override
  Future<Result<void>> closeGitLabItem(Ticket ticket) async =>
      await _gitlab?.closeGitLabItem(ticket) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> reopenGitLabItem(Ticket ticket) async =>
      await _gitlab?.reopenGitLabItem(ticket) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> mergeGitLabMr(
    Ticket ticket, {
    bool? squash,
    bool? removeSourceBranch,
  }) async =>
      await _gitlab?.mergeGitLabMr(
        ticket,
        squash: squash,
        removeSourceBranch: removeSourceBranch,
      ) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> unapproveGitLabMr(Ticket ticket) async =>
      await _gitlab?.unapproveGitLabMr(ticket) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> setGitLabMrDraft(
    Ticket ticket, {
    required bool draft,
  }) async =>
      await _gitlab?.setGitLabMrDraft(ticket, draft: draft) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> approveGitLabMr(Ticket ticket) async =>
      await _gitlab?.approveGitLabMr(ticket) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<void>> rebaseGitLabMr(Ticket ticket) async =>
      await _gitlab?.rebaseGitLabMr(ticket) ??
      const Err(AuthFailure('GitLab service not wired'));

  @override
  Future<Result<List<ProviderLabelOption>>> listGitLabLabels(
    Ticket ticket,
  ) async => await _gitlab?.listGitLabLabels(ticket) ?? const Ok([]);

  @override
  Future<Result<void>> setGitLabLabels(
    Ticket ticket,
    List<String> labels,
  ) async => await _gitlab?.setGitLabLabels(ticket, labels) ?? const Ok(null);

  @override
  Future<Result<List<ProviderMilestoneOption>>> listGitLabMilestones(
    Ticket ticket,
  ) async => await _gitlab?.listGitLabMilestones(ticket) ?? const Ok([]);

  @override
  Future<Result<void>> setGitLabMilestone(
    Ticket ticket,
    int? milestoneId,
  ) async =>
      await _gitlab?.setGitLabMilestone(ticket, milestoneId) ?? const Ok(null);

  @override
  Future<Result<void>> updateGitLabTimeTracking(
    Ticket ticket, {
    String? estimate,
    String? spent,
    bool resetEstimate = false,
    bool resetSpent = false,
  }) async =>
      await _gitlab?.updateGitLabTimeTracking(
        ticket,
        estimate: estimate,
        spent: spent,
        resetEstimate: resetEstimate,
        resetSpent: resetSpent,
      ) ??
      const Ok(null);

  @override
  Future<Result<List<RepoCommit>>> listMergeRequestCommits(
    Ticket ticket,
  ) async => await _gitlab?.listMergeRequestCommits(ticket) ?? const Ok([]);

  @override
  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(
    Ticket ticket,
  ) async => await _gitlab?.listMergeRequestChanges(ticket) ?? const Ok([]);

  @override
  Future<Result<List<String>>> syncGitLabProjectItems({
    required String accountId,
    required String projectId,
    required bool mergeRequests,
  }) => _track(
    accountId,
    () async =>
        await _gitlab?.syncGitLabProjectItems(
          accountId: accountId,
          projectId: projectId,
          mergeRequests: mergeRequests,
        ) ??
        const Ok([]),
  );

  @override
  Future<Result<List<String>>> syncGitLabMine(String accountId) => _track(
    accountId,
    () async => await _gitlab?.syncGitLabMine(accountId) ?? const Ok([]),
  );

  @override
  Future<String?> gitlabServerVersion(String accountId) async =>
      await _gitlab?.gitlabServerVersion(accountId);

  // ---- GitHub PR Service ----

  @override
  Future<Result<void>> closeGitHubItem(Ticket ticket) async =>
      await _github?.closeGitHubItem(ticket) ??
      const Err(AuthFailure('GitHub service not wired'));

  @override
  Future<Result<void>> reopenGitHubItem(Ticket ticket) async =>
      await _github?.reopenGitHubItem(ticket) ??
      const Err(AuthFailure('GitHub service not wired'));

  @override
  Future<Result<void>> mergeGitHubPr(Ticket ticket) async =>
      await _github?.mergeGitHubPr(ticket) ??
      const Err(AuthFailure('GitHub service not wired'));

  @override
  Future<Result<void>> updateGitHubPrBranch(Ticket ticket) async =>
      await _github?.updateGitHubPrBranch(ticket) ??
      const Err(AuthFailure('GitHub service not wired'));

  @override
  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket) async =>
      await _github?.listPullCommits(ticket) ?? const Ok([]);

  @override
  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket) async =>
      await _github?.listPullFiles(ticket) ?? const Ok([]);

  @override
  Future<Result<List<String>>> syncGitHubRepoItems({
    required String accountId,
    required String repoId,
    required bool pullRequests,
  }) => _track(
    accountId,
    () async =>
        await _github?.syncGitHubRepoItems(
          accountId: accountId,
          repoId: repoId,
          pullRequests: pullRequests,
        ) ??
        const Ok([]),
  );

  @override
  Future<Result<List<String>>> syncGitHubMine(String accountId) => _track(
    accountId,
    () async => await _github?.syncGitHubMine(accountId) ?? const Ok([]),
  );

  // ---- ZenTao Ticket Service ----

  @override
  Future<Result<String>> fetchZenTaoTicket({
    required String host,
    required String type,
    required String id,
  }) async =>
      await _zentao?.fetchZenTaoTicket(host: host, type: type, id: id) ??
      const Err(NotFoundFailure('ZenTao service not wired'));

  @override
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  ) async =>
      await _zentao?.listProjectExecutions(accountId, projectId) ??
      const Ok([]);

  @override
  Future<Result<Map<String, dynamic>>> fetchZenTaoMessages(
    String accountId,
  ) async => await _zentao?.fetchZenTaoMessages(accountId) ?? const Ok({});

  @override
  Future<Result<void>> zenTaoMessageAction(
    String accountId,
    String action,
  ) async =>
      await _zentao?.zenTaoMessageAction(accountId, action) ?? const Ok(null);

  @override
  Future<Result<Map<String, dynamic>>> fetchZenTaoUserInfo(
    String accountId, {
    required String fields,
    required int limit,
  }) async =>
      await _zentao?.fetchZenTaoUserInfo(
        accountId,
        fields: fields,
        limit: limit,
      ) ??
      const Ok({});

  // ---- ZenTao Workflow bug actions ----

  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async =>
      await _workflow?.confirmBug(
        ticket,
        assignee: assignee,
        comment: comment,
      ) ??
      const Err(AuthFailure('ZenTao workflow not wired'));

  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
  }) async =>
      await _workflow?.activateBug(
        ticket,
        build: build,
        assignee: assignee,
        comment: comment,
      ) ??
      const Err(AuthFailure('ZenTao workflow not wired'));

  Future<Result<void>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? build,
    String? assignee,
    String? comment,
  }) async =>
      await _workflow?.resolveBug(
        ticket,
        resolution: resolution,
        build: build,
        assignee: assignee,
        comment: comment,
      ) ??
      const Err(AuthFailure('ZenTao workflow not wired'));

  Future<Object?> zenTaoClientFor(String accountId) => rawClientFor(accountId);
}
