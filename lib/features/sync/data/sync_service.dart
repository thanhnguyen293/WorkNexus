import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../data/local/mappers.dart';
import '../../connections/data/gitlab/gitlab_adapter.dart';
import '../../connections/data/gitlab/gitlab_client.dart';
import '../../connections/data/gitlab/gitlab_normalize.dart';
import '../../connections/data/provider_adapter_factory.dart';
import '../../connections/data/zentao/zentao_client.dart';

/// Prefixes of synthetic board-membership labels added at list-sync time (e.g.
/// `zentao-product:<id>` for bug boards, `zentao-execution:<id>` for task
/// boards) that the provider's detail endpoint doesn't return. The native
/// boards filter on these, so a detail refresh must keep them.
const List<String> kSyntheticLabelPrefixes = <String>[
  'zentao-product:',
  'zentao-execution:',
  'gitlab-project:',
];

/// Merges a detail-fetch's [detailLabels] with the synthetic board-membership
/// labels ([kSyntheticLabelPrefixes]) carried on the already-stored
/// [existingLabels]. The detail endpoint omits those synthetic labels, so
/// without this a detail refresh would silently drop the ticket from its board.
List<String> mergeDetailLabels(
  List<String> detailLabels,
  List<String> existingLabels,
) {
  final preserved = existingLabels.where(
    (l) =>
        kSyntheticLabelPrefixes.any(l.startsWith) && !detailLabels.contains(l),
  );
  return [...detailLabels, ...preserved];
}

/// Pulls assigned tickets from a provider account and writes them (plus derived
/// projects) into drift, from where the board reads reactively.
class SyncService {
  SyncService(this._db, this._credentials);

  final AppDatabase _db;
  final CredentialStore _credentials;

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
    final adapter = buildProviderAdapter(account, secret);
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
    return adapter.listProducts();
  }

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

  /// Fetches one ZenTao bug **tab** ([browseType]) for a product — a server-side
  /// filtered view (unclosed / assigned-to-me / resolved-by-me / …) — upserts
  /// its bugs into drift (local-first: the board still renders from the DB), and
  /// returns the ids of the bugs in that tab so the board can show just that
  /// slice. Called fresh on every tab switch.
  Future<Result<List<String>>> syncProductBugsTab({
    required String accountId,
    required String productId,
    required String browseType,
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
    final res = await adapter.listProductBugs(
      productId,
      browseType: browseType,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok([for (final t in value.tickets) t.id]);
    }
  }

  Future<Result<List<ProviderProject>>> listProjects(String accountId) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProjects();
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

  Future<Result<int>> syncExecutionTasks(ProviderExecution execution) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(execution.accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(execution.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listExecutionTasks(execution.id);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  /// Fetches one GitLab project's recent issues OR merge requests (chosen by
  /// [mergeRequests]), tags each with a synthetic `gitlab-project:<id>` label,
  /// upserts them into drift (local-first), and returns their ids so the board
  /// renders just that slice. Mirrors [syncProductBugsTab] for GitLab; routes
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
        final label = 'gitlab-project:$projectId';
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
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
    final adapter = buildProviderAdapter(account, secret);
    if (adapter == null) return const Ok(null);

    final detail = await adapter.getTicket(ticket);
    if (detail case Ok(:final value)) {
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
      );
      await _db
          .into(_db.tickets)
          .insertOnConflictUpdate(ticketToCompanion(merged));
    }

    final comments = await adapter.listComments(ticket);
    final activity = await adapter.listActivity(ticket);
    await _db.transaction(() async {
      if (comments case Ok(:final value)) {
        // Replace provider comments (keep the user's internal notes) so stale
        // rows from a previous sync don't linger.
        await (_db.delete(_db.comments)..where(
              (c) => c.ticketId.equals(ticket.id) & c.origin.equals('provider'),
            ))
            .go();
        for (final c in value) {
          await _db
              .into(_db.comments)
              .insertOnConflictUpdate(commentToCompanion(c));
        }
      }
      if (activity case Ok(:final value)) {
        await (_db.delete(
          _db.activities,
        )..where((a) => a.ticketId.equals(ticket.id))).go();
        for (final e in value) {
          await _db
              .into(_db.activities)
              .insertOnConflictUpdate(activityToCompanion(e));
        }
      }
    });
    return const Ok(null);
  }

  // ---- provider actions (assign / resolve) ----

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
    return buildProviderAdapter(account, secret);
  }

  /// Users the ticket can be assigned to (empty when unavailable). GitLab has no
  /// account-wide assignable list, so its members are fetched per-project.
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) return const Ok(<ProviderUser>[]);
    if (adapter is GitLabAdapter) return adapter.listProjectMembers(ticket);
    return adapter.listUsers();
  }

  /// Reassigns the ticket, then refreshes its cached detail/status/history.
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
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

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
    await syncTicketDetail(ticket);
    await _optimisticallyUpdateTicket(optimistic);
    return const Ok(null);
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
    await syncTicketDetail(ticket);
    await _optimisticallyUpdateTicket(optimistic);
    return const Ok(null);
  }

  // ---- GitLab actions (close / reopen / merge) ----

  /// Closes a GitLab issue or MR, then refreshes its cached detail/status.
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

  /// Optimistically applies [optimistic], runs a GitLab-specific [action]
  /// through the concrete adapter, refreshes the ticket detail on success, and
  /// rolls back to [ticket] on failure. Like [resolveBug]/[activateBug] but
  /// deliberately without their post-refresh re-assert: GitLab is strongly
  /// consistent, so the [syncTicketDetail] fetch already reflects the new state
  /// (no stale-read lag to paper over — re-asserting the guess could overwrite
  /// the authoritative refreshed value).
  Future<Result<void>> _gitlabAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<bool>> Function(GitLabAdapter adapter) action,
  ) async {
    await _optimisticallyUpdateTicket(optimistic);
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter is! GitLabAdapter) {
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

  // ---- inline image loading (authenticated + self-signed TLS) ----

  final Map<String, ZenTaoClient> _zenClients = {};
  final Map<String, GitLabClient> _gitlabClients = {};

  /// Fetches the bytes for an inline image referenced by [ticket]'s rich text,
  /// via the ticket account's authenticated client (ZenTao session or GitLab
  /// PAT). Returns null if the account has no stored credentials or the fetch
  /// fails. Only the matching provider's client is non-null.
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) async {
    try {
      final zen = await _zenClientFor(ticket.accountId);
      if (zen != null) return await zen.fetchBytes(url);
      final gitlab = await _gitlabClientFor(ticket.accountId);
      if (gitlab != null) return await gitlab.fetchBytes(url);
    } catch (_) {}
    return null;
  }

  /// Downloads a ticket [attachment] through the account's authenticated client
  /// into a per-session temp cache and returns the local file path, so the
  /// in-app viewer can display images/videos directly. Returns null if the
  /// account lacks credentials or the download fails.
  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment att) async {
    final client = await _zenClientFor(ticket.accountId);
    if (client == null) return null;
    try {
      final dir = Directory(
        '${Directory.systemTemp.path}/worknexus_attachments',
      );
      await dir.create(recursive: true);
      final file = File('${dir.path}/${att.id}_${_safeName(att.title)}');
      // Reuse an already-downloaded file (viewer reopen, download after view).
      if (await file.exists() && await file.length() > 0) return file.path;
      final bytes = await client.downloadBytes(att.url);
      if (bytes == null) return null;
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

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

  Future<ZenTaoClient?> _zenClientFor(String accountId) async {
    final cached = _zenClients[accountId];
    if (cached != null) return cached;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    if (account.providerType != ProviderType.zentao) return null;
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    final client = ZenTaoClient(
      baseUrl: account.baseUrl ?? '',
      account: account.handle,
      password: secret,
    );
    _zenClients[accountId] = client;
    return client;
  }

  /// A cached authenticated [GitLabClient] for [accountId], or null when the
  /// account isn't GitLab / has no stored credentials. Used for inline image
  /// bytes (`/uploads/…`) that need the PAT.
  Future<GitLabClient?> _gitlabClientFor(String accountId) async {
    final cached = _gitlabClients[accountId];
    if (cached != null) return cached;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    if (account.providerType != ProviderType.gitlab) return null;
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    final client = GitLabClient(baseUrl: account.baseUrl ?? '', token: secret);
    _gitlabClients[accountId] = client;
    return client;
  }

  Future<void> _upsert(Account account, List<Ticket> tickets) async {
    await _db.batch((b) {
      b.insert(
        _db.accounts,
        accountToCompanion(account),
        onConflict: DoUpdate((_) => accountToCompanion(account)),
      );
      final projects = <String, Project>{};
      for (final t in tickets) {
        projects.putIfAbsent(
          t.projectId,
          () => Project(
            id: t.projectId,
            accountId: account.id,
            name: t.projectId.split(':').skip(1).join(':'),
          ),
        );
      }
      for (final p in projects.values) {
        b.insert(
          _db.projects,
          projectToCompanion(p),
          onConflict: DoUpdate((_) => projectToCompanion(p)),
        );
      }
      for (final t in tickets) {
        b.insert(
          _db.tickets,
          ticketToCompanion(t),
          onConflict: DoUpdate((_) => ticketToCompanion(t)),
        );
      }
    });
  }
}
