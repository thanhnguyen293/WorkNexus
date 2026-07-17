import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/project.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../data/local/mappers.dart';
import '../../connections/data/provider_adapter_factory.dart';
import '../../connections/data/zentao/zentao_client.dart';

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
      final merged = value.copyWith(
        id: ticket.id,
        accountId: ticket.accountId,
        projectId: ticket.projectId,
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

  /// Users the ticket can be assigned to (empty when unavailable).
  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket) async {
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) return const Ok(<ProviderUser>[]);
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
    final adapter = await _adapterFor(ticket.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.resolveBug(
      ticket,
      resolution: resolution,
      resolvedBuild: build,
      assignee: assignee,
      comment: comment,
    );
    if (res case Err(:final failure)) return Err(failure);
    await syncTicketDetail(ticket);
    return const Ok(null);
  }

  // ---- inline image loading (authenticated + self-signed TLS) ----

  final Map<String, ZenTaoClient> _zenClients = {};

  /// Fetches the bytes for an inline image referenced by [ticket]'s rich text,
  /// via the ticket account's authenticated client. Returns null if the account
  /// has no stored credentials or the fetch fails.
  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url) async {
    final client = await _zenClientFor(ticket.accountId);
    if (client == null) return null;
    try {
      return await client.fetchBytes(url);
    } catch (_) {
      return null;
    }
  }

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
