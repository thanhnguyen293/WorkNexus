import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/cache/byte_lru_cache.dart';
import '../../../core/data/mappers/mappers.dart';
import '../../../core/database/database.dart';
import '../../../core/domain/adapters/account_sync_service.dart';
import '../../../core/domain/adapters/github_pr_adapter.dart';
import '../../../core/domain/adapters/gitlab_mr_adapter.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/adapters/provider_adapter_registry.dart';
import '../../../core/domain/adapters/ticket_detail_service.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/activity_event.dart';
import '../../../core/domain/entities/comment.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/repositories/sync_status_repository.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import 'attachment_file_cache.dart';
import 'merge_detail_labels.dart';
import 'provider_adapter_pool.dart';
import 'source_list_cache.dart';
import 'sync_status_tracking.dart';
import 'ticket_store.dart';

/// Provider-agnostic coordinator implementing [TicketDetailService] and [AccountSyncService].
/// Registered once, so its [ProviderAdapterPool] is the only one.
class SyncCoordinator implements TicketDetailService, AccountSyncService {
  SyncCoordinator(
    this._db,
    this._credentials, {
    required this._registry,
    AttachmentFileCache? attachmentCache,
    SyncStatusRepository? statusRepository,
  }) : _attachmentCache = attachmentCache ?? AttachmentFileCache(),
       _statusRepo = statusRepository,
       _adapters = ProviderAdapterPool(_db, _credentials, _registry),
       _store = TicketStore(_db),
       _listCache = SourceListCache(_db);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final ProviderAdapterRegistry _registry;
  final AttachmentFileCache _attachmentCache;
  final SyncStatusRepository? _statusRepo;
  final ProviderAdapterPool _adapters;
  final TicketStore _store;
  final SourceListCache _listCache;
  final ByteLruCache _imageCache = ByteLruCache();
  final Map<String, DateTime> _imageMisses = {};
  static const _imageRetryAfter = Duration(minutes: 5);

  AppDatabase get db => _db;
  CredentialStore get credentials => _credentials;
  ProviderAdapterRegistry get registry => _registry;

  /// Runs the sync [action] for [accountId], reporting its sync status.
  Future<T> trackSync<T>(String accountId, Future<T> Function() action) =>
      trackSyncStatus(_statusRepo, accountId, action);

  @override
  Future<Result<int>> syncAccount(Account account) =>
      trackSync(account.id, () => _syncAccount(account));

  Future<Result<int>> _syncAccount(Account account) async {
    final ref = account.credentialsRef;
    if (ref == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final secret = await _credentials.read(ref);
    if (secret == null) {
      return const Err(AuthFailure('Stored credentials not found in keychain'));
    }
    final adapter = buildAdapter(account, secret);
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
        await upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  @override
  Future<Result<int>> syncAccountById(String accountId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return const Err(NotFoundFailure('No such account'));
    return syncAccount(accountFromRow(row));
  }

  Future<Result<List<ProviderProduct>>> listProducts(String accountId) async {
    final adapter = await adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProducts();
    if (res case Ok(:final value)) {
      await _listCache.saveProducts(accountId, value);
    }
    return res;
  }

  Future<List<ProviderProduct>?> cachedProducts(String accountId) =>
      _listCache.readProducts(accountId);

  Future<Result<List<ProviderProject>>> listProjects(String accountId) async {
    final adapter = await adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProjects();
    if (res case Ok(:final value)) {
      final named = await _keepProgramNames(accountId, value);
      await _listCache.saveProjects(accountId, named);
      return Ok(named);
    }
    return res;
  }

  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _listCache.readProjects(accountId);

  /// Program names a fetch could not get (`/programs` failing this time)
  /// from the last list that had them, so the grouping does not come and go.
  Future<List<ProviderProject>> _keepProgramNames(
    String accountId,
    List<ProviderProject> projects,
  ) async {
    if (!projects.any((p) => p.programId != null && p.programName == null)) {
      return projects;
    }
    final cached =
        await _listCache.readProjects(accountId) ?? const <ProviderProject>[];
    final known = <String, String>{
      for (final p in cached)
        if ((p.programId, p.programName) case (final id?, final name?))
          id: name,
    };
    return [
      for (final p in projects)
        ProviderProject(
          id: p.id,
          name: p.name,
          accountId: p.accountId,
          programId: p.programId,
          programName: p.programName ?? known[p.programId],
        ),
    ];
  }

  // Not tracked: one ticket's refresh (and its own failures, like a deleted
  // ticket) is no news about the account's sync.
  @override
  Future<Result<void>> syncTicketDetail(Ticket ticket) async {
    final adapter = await adapterFor(ticket.accountId);
    if (adapter == null) return const Ok(null);

    final detail = await adapter.getTicket(ticket);
    if (detail case Err(:final failure)) return Err(failure);
    final value = (detail as Ok<Ticket>).value;

    final merged = value.copyWith(
      id: ticket.id,
      accountId: ticket.accountId,
      projectId: ticket.projectId,
      labels: mergeDetailLabels(value.labels, ticket.labels),
      providerEntity: preserveLabelColors(
        value.providerEntity,
        ticket.providerEntity,
      ),
    );
    // Only rows that differ are written (an unchanged refresh must not re-run
    // every watch over these tables); compared against the stored row, so the
    // server's answer still replaces an optimistic guess.
    await _store.writeIfChanged(merged);

    // Concurrently; `Future.wait` keeps an adapter's own exception type.
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
    final (projectPath, projectId) = switch (ticket.providerEntity) {
      GitLabItemEntity(:final projectPath, :final projectId) => (
        projectPath,
        projectId,
      ),
      _ => (null, null),
    };
    final Uint8List? bytes;
    try {
      final adapter = await adapterFor(ticket.accountId);
      if (adapter == null) return null;
      bytes = await adapter.fetchBytes(
        url,
        projectPath: projectPath,
        projectId: projectId?.toString(),
      );
    } catch (_) {
      // A failed request (offline, a timeout) is no answer: ask again later.
      return null;
    }
    if (bytes != null) {
      _imageCache.put(key, bytes);
    } else {
      // The provider answered "no" (a deleted file, a dead link): each try
      // costs requests and, on ZenTao, a re-login, so it rests a while.
      _imageMisses[key] = now;
    }
    return bytes;
  }

  @override
  Future<String?> cacheAttachment(Ticket ticket, TicketAttachment att) async {
    final adapter = await adapterFor(ticket.accountId);
    if (adapter == null) return null;
    try {
      final safeName = _safeName(att.title);
      final existing = await _attachmentCache.existing(att.id, safeName);
      if (existing != null) return existing;
      final bytes = await adapter.downloadBytes(att.url);
      if (bytes == null) return null;
      return await _attachmentCache.store(att.id, safeName, bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> purgeAttachmentCache() => _attachmentCache.purge();

  @override
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

  @override
  Future<Result<void>> postComment(Ticket ticket, String body) async {
    final adapter = await adapterFor(ticket.accountId);
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

  @override
  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    final adapter = await adapterFor(ticket.accountId);
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

  @override
  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins) async {
    final adapter = await adapterFor(ticket.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final Result<void> res;
    if (adapter is GitLabMrAdapter) {
      res = await adapter.setReviewers(ticket, logins);
    } else if (adapter is GitHubPrAdapter) {
      res = await adapter.setReviewers(ticket, logins);
    } else {
      return const Err(UnexpectedFailure('Reviewers are GitLab/GitHub only'));
    }
    if (res case Err(:final failure)) return Err(failure);
    return syncTicketDetail(ticket);
  }

  @override
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) async {
    final adapter = await adapterFor(ticket.accountId);
    if (adapter == null) return const Ok(<ProviderUser>[]);
    if (adapter is GitLabMrAdapter) return adapter.listProjectMembers(ticket);
    if (adapter is GitHubPrAdapter) return adapter.listRepoAssignees(ticket);
    return adapter.listUsers();
  }

  Future<Result<void>> runOptimisticAction(
    Ticket ticket,
    Ticket optimistic,
    Future<Result<void>> Function() action,
  ) async {
    await optimisticallyUpdateTicket(optimistic);
    final Result<void> res;
    try {
      res = await action();
    } catch (_) {
      await rollbackTicket(ticket);
      rethrow;
    }
    if (res case Err(:final failure)) {
      await rollbackTicket(ticket);
      return Err(failure);
    }
    // The action already landed on the server: a failed refresh must not roll
    // the ticket back to its pre-action state, so it runs outside the try.
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

  Future<void> optimisticallyUpdateTicket(Ticket ticket) async {
    await _db
        .into(_db.tickets)
        .insertOnConflictUpdate(ticketToCompanion(ticket));
  }

  Future<void> rollbackTicket(Ticket ticket) =>
      optimisticallyUpdateTicket(ticket);

  Future<Object?> rawClientFor(String accountId) async {
    final adapter = await adapterFor(accountId);
    return adapter?.rawClient;
  }

  ProviderAdapter? buildAdapter(Account account, String secret) =>
      _adapters.build(account, secret);

  Future<ProviderAdapter?> adapterFor(String accountId) =>
      _adapters.forAccount(accountId);

  Future<void> upsert(Account account, List<Ticket> tickets) =>
      _store.writeSynced(account, tickets);
}
