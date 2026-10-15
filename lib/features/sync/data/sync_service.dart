import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/adapters/github_pr_service.dart';
import '../../../core/domain/adapters/gitlab_mr_adapter.dart';
import '../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/repo_change.dart';
import '../../../core/domain/value_objects/ticket_sort.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/domain/value_objects/zentao_ticket_id.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../core/util/cancel_signal.dart';
import '../../../core/util/synthetic_labels.dart';
import '../../../data/local/mappers.dart';
import '../../board/domain/repositories/zentao_view_pages.dart';
import '../../connections/data/github/github_adapter.dart';
import '../../connections/data/github/github_client.dart';
import '../../connections/data/github/github_normalize.dart';
import '../../connections/data/gitlab/gitlab_adapter.dart';
import '../../connections/data/gitlab/gitlab_client.dart';
import '../../connections/data/gitlab/gitlab_normalize.dart';
import '../../connections/data/provider_adapter_factory.dart';
import '../../connections/data/zentao/zentao_adapter.dart';
import '../../connections/data/zentao/zentao_client.dart';
import '../../task_detail/domain/repositories/zentao_task_bugs.dart';
import 'attachment_file_cache.dart';
import 'byte_lru_cache.dart';
import 'source_list_cache.dart';
import 'task_bugs_coverage.dart';
import 'ticket_store.dart';

/// Pulls assigned tickets from a provider account and writes them (plus derived
/// projects) into drift, from where the board reads reactively.
class SyncService
    implements
        GitLabMrService,
        GitHubPrService,
        ZenTaoTicketService,
        ZenTaoViewPages,
        ZenTaoTaskBugs {
  SyncService(
    this._db,
    this._credentials, {
    AttachmentFileCache? attachmentCache,
  }) : _attachmentCache = attachmentCache ?? AttachmentFileCache(),
       _listCache = SourceListCache(_db),
       _store = TicketStore(_db);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final AttachmentFileCache _attachmentCache;
  final SourceListCache _listCache;
  final TicketStore _store;

  /// Returns the number of tickets synced, or a [Failure].
  Future<Result<int>> syncAccount(Account account) async {
    final ref = account.credentialsRef;
    if (ref == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final secret = await _credentials.read(ref);
    if (secret == null) {
      return const Err(AuthFailure('Stored credentials not found in keychain'));
    }
    final adapter = _buildAdapter(account, secret);
    if (adapter == null) {
      return Err(
        UnexpectedFailure(
          '${account.providerType.displayName} sync is not implemented yet',
        ),
      );
    }

    final res = await adapter.listAssignedTickets();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  Future<Result<List<ProviderProduct>>> listProducts(String accountId) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProducts();
    if (res case Ok(:final value)) {
      await _listCache.saveProducts(accountId, value);
    }
    return res;
  }

  /// The products [listProducts] last returned for [accountId], or null when
  /// none were stored yet — lets the sidebar paint before the network answers.
  Future<List<ProviderProduct>?> cachedProducts(String accountId) =>
      _listCache.readProducts(accountId);

  Future<Result<int>> syncProductBugs(ProviderProduct product) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(product.accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(product.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProductBugs(product.id);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  /// Fetches one [page] of a product's ZenTao bug view [browseType] (newest
  /// first), upserts its bugs into drift — local-first: the board renders from
  /// the DB — and returns the page so the board can tell which bugs belong to
  /// the view and whether more follow. Not cached: the board keeps the pages it
  /// has loaded and asks again only to load more or to refresh.
  @override
  Future<Result<ViewPage>> syncProductBugsPage({
    required String accountId,
    required String productId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProductBugsPage(
      productId,
      browseType: browseType,
      page: page,
      limit: limit,
      sort: sort,
      cancel: cancel,
    );
    if (res case Ok(:final value)) await _upsert(account, value.tickets);
    return res;
  }

  /// What recent reads of each execution's bug list covered, by
  /// `accountId:executionId` (see [syncTaskBugs]).
  final _taskBugsCoverage = <String, TaskBugsCoverage>{};

  /// Stores task [taskId]'s bugs (local-first: the task detail reads a task's
  /// related bugs from the DB), read from its execution's bug list — unless
  /// a read of it in the last few minutes covered the task already.
  @override
  Future<Result<void>> syncTaskBugs({
    required String accountId,
    required String executionId,
    required String taskId,
  }) async {
    final task = int.tryParse(taskId);
    if (task == null) return const Ok(null);
    final key = '$accountId:$executionId';
    if (_taskBugsCoverage[key]?.covers(task, DateTime.now()) ?? false) {
      return const Ok(null);
    }
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final adapter = await _adapterFor(accountId);
    if (adapter is! ZenTaoAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    final res = await adapter.listTaskBugs(executionId, taskId: task);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(accountFromRow(accountRow), value.bugs);
        _taskBugsCoverage[key] = TaskBugsCoverage(
          at: DateTime.now(),
          complete: value.complete,
          above: value.above,
          tasks: {task},
        );
        return const Ok(null);
    }
  }

  Future<Result<List<ProviderProject>>> listProjects(String accountId) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProjects();
    if (res case Ok(:final value)) {
      await _listCache.saveProjects(accountId, value);
    }
    return res;
  }

  /// The projects/repos [listProjects] last returned for [accountId], or null
  /// when none were stored yet.
  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _listCache.readProjects(accountId);

  /// [syncAccount] by id: fetches every ticket assigned to the account's user
  /// (all pages) into drift. Returns how many were synced.
  Future<Result<int>> syncAccountById(String accountId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return const Err(NotFoundFailure('No such account'));
    return syncAccount(accountFromRow(row));
  }

  /// The raw ZenTao web-notification view for [accountId] (pooled client).
  Future<Result<Map<String, dynamic>>> fetchZenTaoMessages(
    String accountId,
  ) async {
    final adapter = await _adapterFor(accountId);
    if (adapter is! ZenTaoAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.fetchMessages();
  }

  /// Runs ZenTao message [action] (e.g. `ajaxMarkRead-12`) for [accountId].
  Future<Result<void>> zenTaoMessageAction(
    String accountId,
    String action,
  ) async {
    final adapter = await _adapterFor(accountId);
    if (adapter is! ZenTaoAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.messageAction(action);
  }

  /// The raw ZenTao `GET /user?fields=…` reply for [accountId], through the
  /// account's pooled client so it shares (rather than rotates) the session.
  Future<Result<Map<String, dynamic>>> fetchZenTaoUserInfo(
    String accountId, {
    required String fields,
    required int limit,
  }) async {
    final adapter = await _adapterFor(accountId);
    if (adapter is! ZenTaoAdapter) {
      return const Err(AuthFailure('No signed-in ZenTao account'));
    }
    return adapter.fetchUserInfo(fields: fields, limit: limit);
  }

  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  ) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProjectExecutions(projectId);
  }

  /// Fetches one [page] of an execution's ZenTao task view [browseType] (a task
  /// status, newest first), upserts its tasks into drift — local-first: the
  /// board renders from the DB — and returns the page so the board can tell
  /// which tasks belong to the view and whether more follow. Not cached: the
  /// board keeps the pages it has loaded and asks again only to load more or to
  /// refresh.
  @override
  Future<Result<ViewPage>> syncExecutionTasksPage({
    required String accountId,
    required String executionId,
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listExecutionTasksPage(
      executionId,
      browseType: browseType,
      page: page,
      limit: limit,
      sort: sort,
      cancel: cancel,
    );
    if (res case Ok(:final value)) await _upsert(account, value.tickets);
    return res;
  }

  /// Fetches one GitLab project's recent issues OR merge requests (chosen by
  /// [mergeRequests]), tags each with a synthetic `gitlab-project:<id>` label,
  /// upserts them into drift (local-first), and returns their ids so the board
  /// renders just that slice. Mirrors the ZenTao bug board for GitLab; routes
  /// through the concrete [GitLabAdapter] (GitLab-specific fetch, not on the
  /// shared interface).
  Future<Result<List<String>>> syncGitLabProjectItems({
    required String accountId,
    required String projectId,
    required bool mergeRequests,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProjectItems(
      projectId,
      kind: mergeRequests ? GitLabKind.mergeRequest : GitLabKind.issue,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = gitlabProjectLabel(projectId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches one GitHub repo's recent issues OR pull requests (chosen by
  /// [pullRequests]), tags each with a synthetic `github-repo:<repo>` label,
  /// upserts them into drift (local-first), and returns their ids so the board
  /// renders just that slice. Mirrors [syncGitLabProjectItems] for GitHub; routes
  /// through the concrete [GitHubAdapter] (GitHub-specific fetch, not on the
  /// shared interface). [repoId] is the `owner/name` slug.
  Future<Result<List<String>>> syncGitHubRepoItems({
    required String accountId,
    required String repoId,
    required bool pullRequests,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listRepoItems(
      repoId,
      kind: pullRequests ? GitHubKind.pullRequest : GitHubKind.issue,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = githubRepoLabel(repoId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches the current user's assigned + review-requested merge requests across
  /// all GitLab projects (the "my merge requests" board), tags each with a
  /// synthetic `gitlab-mine:<accountId>` label, upserts them into drift, and
  /// returns their ids. The label lets the board render this slice from the DB
  /// when offline (the slice id set reconciles it once a sync succeeds).
  Future<Result<List<String>>> syncGitLabMine(String accountId) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitLabAdapter) {
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
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches the current user's assigned + review-requested pull requests across
  /// all GitHub repos (the "my pull requests" board), tags each with a synthetic
  /// `github-mine:<accountId>` label, upserts them, and returns their ids. The
  /// label lets the board render this slice from the DB when offline (the slice
  /// id set reconciles it once a sync succeeds).
  Future<Result<List<String>>> syncGitHubMine(String accountId) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitHubAdapter) {
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
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  @override
  Future<Result<String>> fetchZenTaoTicket({
    required String host,
    required String type,
    required String id,
  }) async {
    final rows = await (_db.select(
      _db.accounts,
    )..where((a) => a.providerType.equals(ProviderType.zentao.name))).get();
    final account = rows
        .map(accountFromRow)
        .where((a) => Uri.tryParse(a.baseUrl ?? '')?.host == host)
        .firstOrNull;
    final credRef = account?.credentialsRef;
    if (account == null || credRef == null) {
      return const Err(NotFoundFailure('No ZenTao account for this link'));
    }
    final secret = await _credentials.read(credRef);
    final adapter = secret == null ? null : _buildAdapter(account, secret);
    if (adapter == null) {
      return const Err(AuthFailure('ZenTao account is not signed in'));
    }
    // Only the type and id matter to the detail request; the rest is filled
    // from the reply.
    final stub = Ticket(
      id: zenTaoTicketId(account.id, type, id),
      accountId: account.id,
      projectId: '${account.id}:$type',
      providerType: ProviderType.zentao,
      externalKey: id,
      externalType: '${type[0].toUpperCase()}${type.substring(1)}',
      title: '',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: '',
      sourceHash: '',
    );
    final detail = await adapter.getTicket(stub);
    switch (detail) {
      case Ok(:final value):
        await _db
            .into(_db.tickets)
            .insertOnConflictUpdate(ticketToCompanion(value));
        return Ok(value.id);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Fetches full detail + comments for a single [ticket] from its provider and
  /// writes them into drift (from where the detail panel reads reactively).
  ///
  /// A no-op for tickets whose account has no stored credentials (e.g. seeded
  /// demo data) — the panel just shows the already-cached content. Network
  /// failures are swallowed so opening a card never throws; cached data stays.
  Future<Result<void>> syncTicketDetail(Ticket ticket) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(ticket.accountId))).getSingleOrNull();
    if (accountRow == null) return const Ok(null);
    final account = accountFromRow(accountRow);
    final credRef = account.credentialsRef;
    if (credRef == null) return const Ok(null);
    final secret = await _credentials.read(credRef);
    if (secret == null) return const Ok(null);
    final adapter = _buildAdapter(account, secret);
    if (adapter == null) return const Ok(null);

    final detail = await adapter.getTicket(ticket);
    if (detail case Err(:final failure)) return Err(failure);
    final value = (detail as Ok<Ticket>).value;
    // Keep the local identity/scope stable; refresh only the content fields.
    // Carry forward synthetic board-membership labels (e.g.
    // `zentao-product:<id>`, added by the product-board sync): the detail
    // endpoint doesn't return them, so dropping them would silently remove
    // the ticket from its product board the moment its detail is opened.
    final merged = value.copyWith(
      id: ticket.id,
      accountId: ticket.accountId,
      projectId: ticket.projectId,
      labels: mergeDetailLabels(value.labels, ticket.labels),
      providerEntity: _preserveLabelColors(
        value.providerEntity,
        ticket.providerEntity,
      ),
    );
    // The store writes only what differs from the stored rows (a refresh that
    // brings nothing new must not re-run every watch over these tables) and
    // compares against the rows, not [ticket], so the server's answer still
    // replaces an optimistic guess that [ticket] predates.
    await _store.writeIfChanged(merged);

    // Independent requests, so one round trip of latency instead of two.
    // `Future.wait` keeps an adapter's own exception type for the caller.
    final [
      comments as Result<List<Comment>>,
      activity as Result<List<ActivityEvent>>,
    ] = await Future.wait<Object>([
      adapter.listComments(ticket),
      adapter.listActivity(ticket),
    ]);
    await _db.transaction(() async {
      if (comments case Ok(:final value)) {
        await _store.replaceProviderComments(ticket.id, value);
      }
      if (activity case Ok(:final value)) {
        await _store.replaceActivity(ticket.id, value);
      }
    });
    return const Ok(null);
  }

  // ---- provider actions (assign / resolve) ----

  /// Builds an adapter over this account's pooled client (see
  /// [zenTaoClientFrom] and the pools below): for ZenTao so the adapter and
  /// the inline-image/attachment loaders never fight over the one session,
  /// for GitLab and GitHub so they keep their connection instead of opening
  /// a new one per sync, detail open and action.
  ProviderAdapter? _buildAdapter(Account account, String secret) =>
      buildProviderAdapter(
        account,
        secret,
        zenClient: account.providerType == ProviderType.zentao
            ? zenTaoClientFrom(account, secret)
            : null,
        gitlabClient: account.providerType == ProviderType.gitlab
            ? _gitlabClientFrom(account, secret)
            : null,
        githubClient: account.providerType == ProviderType.github
            ? _githubClientFrom(account, secret)
            : null,
      );

  /// Builds a live [ProviderAdapter] for the ticket's account, or null when the
  /// account has no stored credentials / provider isn't implemented.
  Future<ProviderAdapter?> _adapterFor(String accountId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    return _buildAdapter(account, secret);
  }

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

  /// Approves a GitLab merge request, then refreshes its cached detail.
  @override
  Future<Result<void>> approveGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.approveMergeRequest(ticket));

  /// Withdraws the user's approval, then refreshes its cached detail.
  @override
  Future<Result<void>> unapproveGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.unapproveMergeRequest(ticket));

  /// Marks a GitLab MR draft / ready, then refreshes its cached detail (the
  /// new title included). The board column follows the draft flag.
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

  /// Rebases a GitLab MR onto its target, then refreshes its cached detail. No
  /// status change — only the merge status flips, which the refresh picks up.
  @override
  Future<Result<void>> rebaseGitLabMr(Ticket ticket) =>
      _gitlabAction(ticket, ticket, (a) => a.rebaseMergeRequest(ticket));

  /// Optimistically applies [optimistic], runs a GitLab-specific [action]
  /// through the GitLab MR adapter contract, refreshes detail on success, and
  /// rolls back to [ticket] on failure. Like [resolveBug]/[activateBug] but
  /// deliberately without their post-refresh re-assert: GitLab is strongly
  /// consistent, so the [syncTicketDetail] fetch already reflects the new state
  /// (no stale-read lag to paper over — re-asserting the guess could overwrite
  /// the authoritative refreshed value).
  Future<Result<void>> _gitlabAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(GitLabMrAdapter adapter) action,
  ) async {
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabMrAdapter) {
      await _rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await action(adapter);
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    return syncTicketDetail(ticket);
  }

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

  /// Optimistically applies [optimistic], runs a GitHub-specific [action] through
  /// the concrete adapter, refreshes the ticket detail on success, and rolls back
  /// to [ticket] on failure. Mirrors [_gitlabAction] (GitHub is likewise strongly
  /// consistent, so no post-refresh re-assert).
  Future<Result<void>> _githubAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(GitHubAdapter adapter) action,
  ) async {
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitHubAdapter) {
      await _rollbackTicket(ticket);
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await action(adapter);
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

  /// Shows [optimistic] at once, runs [action] against the provider, then
  /// refreshes [ticket] from it — or puts [ticket] back when [action] fails.
  /// The refresh brings the provider's own outcome (assignee, hours…).
  Future<Result<void>> runOptimisticAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<void>> Function() action,
  ) async {
    await _optimisticallyUpdateTicket(optimistic);
    final Result<void> res;
    try {
      res = await action();
    } catch (_) {
      await _rollbackTicket(ticket);
      rethrow;
    }
    if (res case Err(:final failure)) {
      await _rollbackTicket(ticket);
      return Err(failure);
    }
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

  Future<void> _optimisticallyUpdateTicket(Ticket ticket) async {
    await _db
        .into(_db.tickets)
        .insertOnConflictUpdate(ticketToCompanion(ticket));
  }

  Future<void> _rollbackTicket(Ticket ticket) =>
      _optimisticallyUpdateTicket(ticket);

  List<String> _withResolution(List<String> labels, String resolution) => [
    ..._withoutResolution(labels),
    'resolution:${resolution.toLowerCase()}',
  ];

  List<String> _withoutResolution(List<String> labels) => [
    for (final label in labels)
      if (!label.toLowerCase().startsWith('resolution:')) label,
  ];

  /// GitLab's single-MR/issue detail endpoint returns label *names* only (no
  /// colors — `with_labels_details` is a list-endpoint feature), so a detail
  /// refresh would drop the palette the list sync captured. Carry the existing
  /// label colors forward when the fresh fetch didn't supply them.
  TicketProviderEntity? _preserveLabelColors(
    TicketProviderEntity? fresh,
    TicketProviderEntity? existing,
  ) {
    if (fresh is GitLabItemEntity &&
        existing is GitLabItemEntity &&
        fresh.labelColors.isEmpty &&
        existing.labelColors.isNotEmpty) {
      return fresh.copyWith(
        labelColors: existing.labelColors,
        labelTextColors: existing.labelTextColors,
      );
    }
    return fresh;
  }

  // ---- detail view: commits + changed files ----

  @override
  Future<Result<List<RepoCommit>>> listMergeRequestCommits(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(
    Ticket ticket,
  ) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored GitLab credentials'));
    }
    return adapter.listMergeRequestChanges(ticket);
  }

  @override
  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullCommits(ticket);
  }

  @override
  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored GitHub credentials'));
    }
    return adapter.listPullFiles(ticket);
  }

  // ---- inline image loading (authenticated + self-signed TLS) ----

  /// One client per account, with the secret it was built for: a reconnect
  /// with a new token or password gets a new client, everything else reuses
  /// the connection (and, for ZenTao, the session).
  final Map<String, (String, ZenTaoClient)> _zenClients = {};
  final Map<String, (String, GitLabClient)> _gitlabClients = {};
  final Map<String, (String, GitHubClient)> _githubClients = {};

  /// Successfully loaded inline-image bytes, keyed by account + url, so the detail
  /// panel reuses a loaded image instead of refetching on every Original/
  /// Translate tab switch. Only successes are cached, so a failed load can retry.
  /// LRU-bounded at 500 MB so it can't grow without limit over the app lifetime.
  final ByteLruCache _imageCache = ByteLruCache();

  /// When an inline image last failed to load, by the same key. A failure
  /// (a deleted file answering with HTML, a dead link) costs up to three
  /// requests including a forced re-login, and every rebuild or tab switch
  /// asked again; within [_imageRetryAfter] the answer is still "no".
  final Map<String, DateTime> _imageMisses = {};
  static const _imageRetryAfter = Duration(minutes: 5);

  /// Fetches the bytes for an inline image referenced by [ticket]'s rich text,
  /// via the ticket account's authenticated client (ZenTao session, GitLab or
  /// GitHub PAT). Returns null if the account has no stored credentials or the
  /// fetch fails. Only the matching provider's client is non-null. Successful
  /// results are cached in [_imageCache].
  @override
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) async {
    final key = '${ticket.accountId}|$url';
    final cached = _imageCache.get(key);
    if (cached != null) return cached;
    final now = DateTime.now();
    if (_imageMisses[key] case final missed?) {
      if (now.difference(missed) < _imageRetryAfter) return null;
      _imageMisses.remove(key);
    }
    final ({Uint8List? bytes, bool answered}) load;
    try {
      load = await _loadTicketImage(ticket, url);
    } catch (_) {
      // A request that failed (offline, a timeout) is not an answer: the
      // next rebuild may ask again.
      return null;
    }
    if (load.bytes case final bytes?) {
      _imageCache.put(key, bytes);
    } else if (load.answered) {
      _imageMisses[key] = now;
    }
    return load.bytes;
  }

  /// The image through the account's client; [answered] when a client was
  /// asked and said no (as opposed to there being no client to ask).
  Future<({Uint8List? bytes, bool answered})> _loadTicketImage(
    Ticket ticket,
    String url,
  ) async {
    final zen = await _zenClientFor(ticket.accountId);
    if (zen != null) {
      return (bytes: await zen.fetchBytes(url), answered: true);
    }
    final gitlab = await _gitlabClientFor(ticket.accountId);
    if (gitlab != null) {
      // A GitLab `/uploads/…` link is project-relative — pass the project ref
      // so the client fetches it via the PAT-readable Markdown uploads API.
      final (projectPath, projectId) = switch (ticket.providerEntity) {
        GitLabItemEntity(:final projectPath, :final projectId) => (
          projectPath,
          projectId,
        ),
        _ => (null, null),
      };
      final bytes = await gitlab.fetchBytes(
        url,
        projectPath: projectPath,
        projectId: projectId,
      );
      return (bytes: bytes, answered: true);
    }
    final github = await _githubClientFor(ticket.accountId);
    if (github != null) {
      return (bytes: await github.fetchBytes(url), answered: true);
    }
    return (bytes: null, answered: false);
  }

  /// Downloads a ticket [attachment] through the account's authenticated client
  /// into a per-session temp cache and returns the local file path, so the
  /// in-app viewer can display images/videos directly. Returns null if the
  /// account lacks credentials or the download fails.
  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment att) async {
    final client = await _zenClientFor(ticket.accountId);
    if (client == null) return null;
    try {
      final safeName = _safeName(att.title);
      // Reuse an already-downloaded file (viewer reopen, download after view).
      final existing = await _attachmentCache.existing(att.id, safeName);
      if (existing != null) return existing;
      final bytes = await client.downloadBytes(att.url);
      if (bytes == null) return null;
      return await _attachmentCache.store(att.id, safeName, bytes);
    } catch (_) {
      return null;
    }
  }

  /// Wipes the on-disk attachment cache. Call once at startup so downloaded
  /// repro videos/screenshots don't accumulate in temp across app sessions.
  Future<void> purgeAttachmentCache() => _attachmentCache.purge();

  /// Copies an already-[cachedPath] attachment into the user's Downloads folder
  /// and reveals it in Finder. Returns the saved path, or null on failure.
  Future<String?> saveAttachmentToDownloads(
    String cachedPath,
    String name,
  ) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final downloads = Directory('$home/Downloads');
      if (!await downloads.exists()) return null;
      final dest = File('${downloads.path}/${_safeName(name)}');
      await File(cachedPath).copy(dest.path);
      await Process.run('open', ['-R', dest.path]);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

  /// The one pooled [ZenTaoClient] for [account], created on first use and
  /// reused thereafter so every path for this account — board/detail sync,
  /// inline images, attachments — shares ONE session. ZenTao invalidates the
  /// previous session id on each login, so separate clients would knock each
  /// other's session out; that race is why inline images failed on a ticket's
  /// first open (the detail sync logged in concurrently on its own client).
  ZenTaoClient zenTaoClientFrom(Account account, String secret) => _pooled(
    _zenClients,
    account.id,
    secret,
    () => ZenTaoClient(
      baseUrl: account.baseUrl ?? '',
      account: account.handle,
      password: secret,
    ),
  );

  GitLabClient _gitlabClientFrom(Account account, String secret) => _pooled(
    _gitlabClients,
    account.id,
    secret,
    () => GitLabClient(baseUrl: account.baseUrl ?? '', token: secret),
  );

  GitHubClient _githubClientFrom(Account account, String secret) => _pooled(
    _githubClients,
    account.id,
    secret,
    () => GitHubClient(baseUrl: account.baseUrl ?? '', token: secret),
  );

  /// The pooled client of [accountId] built for [secret], or a new one from
  /// [build] when there is none yet or the secret changed.
  C _pooled<C>(
    Map<String, (String, C)> pool,
    String accountId,
    String secret,
    C Function() build,
  ) {
    if (pool[accountId] case (
      final pooledSecret,
      final client,
    ) when pooledSecret == secret) {
      return client;
    }
    final client = build();
    pool[accountId] = (secret, client);
    // What the old client could not load may load with the new credentials.
    _imageMisses.removeWhere((key, _) => key.startsWith('$accountId|'));
    return client;
  }

  /// The account's pooled ZenTao client (null without stored credentials), for
  /// work beyond syncing — such as ZenTao's bug and task forms.
  Future<ZenTaoClient?> zenTaoClientFor(String accountId) =>
      _zenClientFor(accountId);

  Future<ZenTaoClient?> _zenClientFor(String accountId) async {
    if (_zenClients[accountId] case (_, final client)) return client;
    final found = await _accountSecret(accountId, ProviderType.zentao);
    return found == null ? null : zenTaoClientFrom(found.account, found.secret);
  }

  /// The stored [provider] account [accountId] with its secret, or null when
  /// there is no such account or it has no stored credentials.
  Future<({Account account, String secret})?> _accountSecret(
    String accountId,
    ProviderType provider,
  ) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    if (account.providerType != provider) return null;
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    return (account: account, secret: secret);
  }

  /// The GitLab instance version for [accountId] (e.g. `16.3.8`), or null when
  /// it isn't a GitLab account / is unavailable. Surfaced on the connected-
  /// accounts row.
  Future<String?> gitlabServerVersion(String accountId) async {
    final client = await _gitlabClientFor(accountId);
    if (client == null) return null;
    return client.version();
  }

  /// A cached authenticated [GitLabClient] for [accountId], or null when the
  /// account isn't GitLab / has no stored credentials. Used for inline image
  /// bytes (`/uploads/…`) that need the PAT.
  Future<GitLabClient?> _gitlabClientFor(String accountId) async {
    if (_gitlabClients[accountId] case (_, final client)) return client;
    final found = await _accountSecret(accountId, ProviderType.gitlab);
    return found == null
        ? null
        : _gitlabClientFrom(found.account, found.secret);
  }

  /// A cached authenticated [GitHubClient] for [accountId], or null when the
  /// account isn't GitHub / has no stored credentials. Used for inline image
  /// bytes that need the PAT (e.g. GitHub Enterprise same-host assets).
  Future<GitHubClient?> _githubClientFor(String accountId) async {
    if (_githubClients[accountId] case (_, final client)) return client;
    final found = await _accountSecret(accountId, ProviderType.github);
    return found == null
        ? null
        : _githubClientFrom(found.account, found.secret);
  }

  Future<void> _upsert(Account account, List<Ticket> tickets) =>
      _store.writeSynced(account, tickets);
}
