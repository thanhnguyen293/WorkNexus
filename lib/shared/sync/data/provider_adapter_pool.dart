import '../../../core/data/mappers/mappers.dart';
import '../../../core/database/database.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/adapters/provider_adapter_registry.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/platform/credential_store.dart';

/// One live [ProviderAdapter] per account, so every path for an account shares
/// ONE provider client — ZenTao drops the previous session on every login.
class ProviderAdapterPool {
  ProviderAdapterPool(this._db, this._credentials, this._registry);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final ProviderAdapterRegistry _registry;
  final Map<String, ({String fingerprint, ProviderAdapter adapter})> _adapters =
      {};

  /// The pooled adapter for [account], rebuilt when its secret or connection
  /// details changed (re-authentication), so a stale token is never reused.
  ProviderAdapter? build(Account account, String secret) {
    final fingerprint = '${account.baseUrl}|${account.handle}|$secret';
    final cached = _adapters[account.id];
    if (cached != null && cached.fingerprint == fingerprint) {
      return cached.adapter;
    }
    final adapter = _registry.createAdapter(account, secret);
    if (adapter != null) {
      _adapters[account.id] = (fingerprint: fingerprint, adapter: adapter);
    } else {
      _adapters.remove(account.id);
    }
    return adapter;
  }

  /// Reads the account and secret on every call (both local and cheap — the
  /// vault is held in memory) so a removed account or a rewritten secret never
  /// gets a stale adapter.
  Future<ProviderAdapter?> forAccount(String accountId) async {
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    final ref = row == null ? null : accountFromRow(row).credentialsRef;
    final secret = ref == null ? null : await _credentials.read(ref);
    if (row == null || secret == null) {
      _adapters.remove(accountId);
      return null;
    }
    return build(accountFromRow(row), secret);
  }
}
