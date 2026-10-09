import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/adapters/github_pr_service.dart';
import '../../../core/domain/adapters/gitlab_mr_adapter.dart';
import '../../../core/domain/adapters/gitlab_mr_service.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/adapters/source_sync_service.dart';
import '../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../core/domain/adapters/zentao_bug_service.dart';
import '../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/repo_change.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../core/util/in_flight.dart';
import '../../../core/util/synthetic_labels.dart';
import '../../../data/local/mappers.dart';
import '../../connections/data/github/github_adapter.dart';
import '../../connections/data/github/github_client.dart';
import '../../connections/data/github/github_normalize.dart';
import '../../connections/data/gitlab/gitlab_adapter.dart';
import '../../connections/data/gitlab/gitlab_client.dart';
import '../../connections/data/gitlab/gitlab_normalize.dart';
import '../../connections/data/provider_adapter_factory.dart';
import '../../connections/data/zentao/zentao_client.dart';
import 'attachment_file_cache.dart';
import 'byte_lru_cache.dart';
import 'timed_slice_cache.dart';

part 'sync_service_sources.dart';
part 'sync_service_detail.dart';
part 'sync_service_actions.dart';
part 'sync_service_mr_actions.dart';
part 'sync_service_media.dart';

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
class SyncService extends _SyncCore
    with
        _SourceSync,
        _TicketDetailSync,
        _TicketActions,
        _MergeRequestActions,
        _TicketMedia {
  SyncService(
    super.db,
    super.credentials, {
    super.zentaoBugTabCache,
    super.zentaoExecutionTaskCache,
    super.attachmentCache,
  });
}

/// State and helpers every part of [SyncService] shares: the database,
/// credentials, slice caches, the pooled provider clients and ticket writes.
abstract class _SyncCore
    implements
        SourceSyncService,
        TicketDetailService,
        ZenTaoBugService,
        ZenTaoTicketService,
        GitLabMrService,
        GitHubPrService {
  _SyncCore(
    this._db,
    this._credentials, {
    TimedSliceCache<List<String>>? zentaoBugTabCache,
    TimedSliceCache<int>? zentaoExecutionTaskCache,
    AttachmentFileCache? attachmentCache,
  }) : _zentaoBugTabCache =
           zentaoBugTabCache ??
           TimedSliceCache<List<String>>(ttl: zentaoTabCacheTtl),
       _zentaoExecutionTaskCache =
           zentaoExecutionTaskCache ??
           TimedSliceCache<int>(ttl: zentaoTabCacheTtl),
       _attachmentCache = attachmentCache ?? AttachmentFileCache();

  static const zentaoTabCacheTtl = Duration(minutes: 15);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final TimedSliceCache<List<String>> _zentaoBugTabCache;
  final TimedSliceCache<int> _zentaoExecutionTaskCache;
  final AttachmentFileCache _attachmentCache;

  final Map<String, ZenTaoClient> _zenClients = {};
  final Map<String, GitLabClient> _gitlabClients = {};
  final Map<String, GitHubClient> _githubClients = {};

  // ---- provider actions (assign / resolve) ----

  /// Builds an adapter that reuses this account's pooled ZenTao session, so the
  /// adapter and the inline-image/attachment loaders never fight over the
  /// session (see [_zenClientFrom]). Non-ZenTao providers authenticate with a
  /// stateless token and need no pooling.
  ProviderAdapter? _buildAdapter(Account account, String secret) =>
      buildProviderAdapter(
        account,
        secret,
        zenClient: account.providerType == ProviderType.zentao
            ? _zenClientFrom(account, secret)
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

  /// The one pooled [ZenTaoClient] for [account], created on first use and
  /// reused thereafter so every path for this account — board/detail sync,
  /// inline images, attachments — shares ONE session. ZenTao invalidates the
  /// previous session id on each login, so separate clients would knock each
  /// other's session out; that race is why inline images failed on a ticket's
  /// first open (the detail sync logged in concurrently on its own client).
  ZenTaoClient _zenClientFrom(Account account, String secret) =>
      _zenClients[account.id] ??= ZenTaoClient(
        baseUrl: account.baseUrl ?? '',
        account: account.handle,
        password: secret,
      );

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
    return _zenClientFrom(account, secret);
  }

  /// The GitLab instance version for [accountId] (e.g. `16.3.8`), or null when
  /// it isn't a GitLab account / is unavailable. Surfaced on the connected-
  /// accounts row.
  @override
  Future<String?> gitlabServerVersion(String accountId) async {
    final client = await _gitlabClientFor(accountId);
    if (client == null) return null;
    return client.version();
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

  /// A cached authenticated [GitHubClient] for [accountId], or null when the
  /// account isn't GitHub / has no stored credentials. Used for inline image
  /// bytes that need the PAT (e.g. GitHub Enterprise same-host assets).
  Future<GitHubClient?> _githubClientFor(String accountId) async {
    final cached = _githubClients[accountId];
    if (cached != null) return cached;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    if (account.providerType != ProviderType.github) return null;
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    final client = GitHubClient(baseUrl: account.baseUrl ?? '', token: secret);
    _githubClients[accountId] = client;
    return client;
  }

  Future<void> _upsert(Account account, List<Ticket> tickets) async {
    final merged = await _carryMembershipLabels(tickets);
    await _db.batch((b) {
      b.insert(
        _db.accounts,
        accountToCompanion(account),
        onConflict: DoUpdate((_) => accountToCompanion(account)),
      );
      final projects = <String, Project>{};
      for (final t in merged) {
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
      for (final t in merged) {
        b.insert(
          _db.tickets,
          ticketToCompanion(t),
          onConflict: DoUpdate((_) => ticketToCompanion(t)),
        );
      }
    });
  }

  /// Carries forward the synthetic board-membership labels
  /// ([kSyntheticLabelPrefixes]) already stored for these tickets. Each list
  /// sync only stamps its own marker (a project board vs. the account-wide
  /// "mine" board), and `_upsert`'s row overwrite would otherwise drop the
  /// others — leaving an item missing from a board it belongs to when the board
  /// renders from the DB offline. Real provider labels still come fresh from the
  /// server. Stale markers reconcile online via each board's slice.
  Future<List<Ticket>> _carryMembershipLabels(List<Ticket> tickets) async {
    if (tickets.isEmpty) return tickets;
    final ids = [for (final t in tickets) t.id];
    final rows = await (_db.select(
      _db.tickets,
    )..where((r) => r.id.isIn(ids))).get();
    final priorLabels = {
      for (final r in rows) r.id: decodeLabels(r.labelsJson),
    };
    return [
      for (final t in tickets)
        if (priorLabels[t.id] case final prior?)
          t.copyWith(labels: mergeDetailLabels(t.labels, prior))
        else
          t,
    ];
  }

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
}
