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
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import 'attachment_file_cache.dart';
import 'merge_detail_labels.dart';
import 'source_list_cache.dart';

/// Provider-agnostic coordinator implementing [TicketDetailService] and [AccountSyncService].
class SyncCoordinator implements TicketDetailService, AccountSyncService {
  SyncCoordinator(
    this._db,
    this._credentials, {
    required this._registry,
    AttachmentFileCache? attachmentCache,
  }) : _attachmentCache = attachmentCache ?? AttachmentFileCache(),
       _listCache = SourceListCache(_db);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final ProviderAdapterRegistry _registry;
  final AttachmentFileCache _attachmentCache;
  final SourceListCache _listCache;
  final ByteLruCache _imageCache = ByteLruCache();
  final Map<String, ProviderAdapter> _adapters = {};

  AppDatabase get db => _db;
  CredentialStore get credentials => _credentials;
  ProviderAdapterRegistry get registry => _registry;

  @override
  Future<Result<int>> syncAccount(Account account) async {
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
      await _listCache.saveProjects(accountId, value);
    }
    return res;
  }

  Future<List<ProviderProject>?> cachedProjects(String accountId) =>
      _listCache.readProjects(accountId);

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
    await _db
        .into(_db.tickets)
        .insertOnConflictUpdate(ticketToCompanion(merged));

    final comments = await adapter.listComments(ticket);
    final activity = await adapter.listActivity(ticket);
    await _db.transaction(() async {
      if (comments case Ok(:final value)) {
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

  @override
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) async {
    final key = '${ticket.accountId}|$url';
    final cached = _imageCache.get(key);
    if (cached != null) return cached;
    final bytes = await _loadTicketImage(ticket, url);
    if (bytes != null) _imageCache.put(key, bytes);
    return bytes;
  }

  Future<Uint8List?> _loadTicketImage(Ticket ticket, String url) async {
    try {
      final adapter = await adapterFor(ticket.accountId);
      if (adapter == null) return null;
      final (projectPath, projectId) = switch (ticket.providerEntity) {
        GitLabItemEntity(:final projectPath, :final projectId) => (
          projectPath,
          projectId,
        ),
        _ => (null, null),
      };
      return await adapter.fetchBytes(
        url,
        projectPath: projectPath,
        projectId: projectId?.toString(),
      );
    } catch (_) {}
    return null;
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
    try {
      final res = await action();
      if (res case Err(:final failure)) {
        await rollbackTicket(ticket);
        return Err(failure);
      }
      await syncTicketDetail(ticket);
      return const Ok(null);
    } catch (_) {
      await rollbackTicket(ticket);
      rethrow;
    }
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

  ProviderAdapter? buildAdapter(Account account, String secret) {
    final cached = _adapters[account.id];
    if (cached != null) return cached;
    final adapter = _registry.createAdapter(account, secret);
    if (adapter != null) {
      _adapters[account.id] = adapter;
    }
    return adapter;
  }

  Future<ProviderAdapter?> adapterFor(String accountId) async {
    final cached = _adapters[accountId];
    if (cached != null) return cached;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (row == null) return null;
    final account = accountFromRow(row);
    final ref = account.credentialsRef;
    if (ref == null) return null;
    final secret = await _credentials.read(ref);
    if (secret == null) return null;
    return buildAdapter(account, secret);
  }

  Future<void> upsert(Account account, List<Ticket> tickets) async {
    final merged = await carryMembershipLabels(_db, tickets);
    await _db.batch((b) {
      b.insert(
        _db.accounts,
        accountToCompanion(account),
        onConflict: DoUpdate((_) => accountToCompanion(account)),
      );
      final projects = {
        for (final t in merged)
          t.projectId: Project(
            id: t.projectId,
            accountId: account.id,
            name: t.projectId.split(':').skip(1).join(':'),
          ),
      };
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
}
