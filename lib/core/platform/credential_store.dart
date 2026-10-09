import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores provider secrets (passwords/tokens) in the OS keychain. The drift DB
/// only ever holds a `credentialsRef` key into this store — never the secret.
///
/// On macOS we disable the data-protection keychain: it requires a signed
/// `keychain-access-groups` entitlement (only present with a real dev-team
/// signing identity), so ad-hoc/local builds hit `-34018 errSecMissingEntitlement`.
/// The legacy login keychain needs no such entitlement.
///
/// All secrets live in **one** keychain item (a JSON map, [vaultKey]): macOS
/// asks to allow access per item, and an ad-hoc signed build is a new app to
/// it each time, so one item means one prompt per launch instead of one per
/// account (plus more as chat and link cards read theirs). The vault is read
/// once and kept for the app's lifetime. Secrets stored one item per account
/// by older versions are moved into it the first time they are read.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  final FlutterSecureStorage _storage;

  /// The keychain item holding every secret.
  static const vaultKey = 'worknexus.vault';

  static String refFor(String accountId) => 'secret:$accountId';

  /// The vault's contents, read once (a failed read is retried next time).
  Future<Map<String, String>>? _vault;

  /// Vault writes run one after another, so none overwrites another's change.
  Future<void> _writes = Future.value();

  Future<Map<String, String>> _load() => _vault ??= () async {
    try {
      final raw = await _storage.read(key: vaultKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      return {
        if (decoded is Map)
          for (final MapEntry(:key, :value) in decoded.entries)
            if (value is String) '$key': value,
      };
    } catch (_) {
      _vault = null;
      rethrow;
    }
  }();

  /// Saves [change] to the vault, after any save already under way.
  Future<void> _save(void Function(Map<String, String> vault) change) {
    final done = _writes.then((_) async {
      final vault = await _load();
      change(vault);
      await _storage.write(key: vaultKey, value: jsonEncode(vault));
    });
    _writes = done.catchError((_) {});
    return done;
  }

  Future<void> write(String ref, String secret) =>
      _save((vault) => vault[ref] = secret);

  /// Moves of older items under way, so readers at once share one.
  final _moving = <String, Future<String?>>{};

  Future<String?> read(String ref) async {
    final vault = await _load();
    if (vault[ref] case final secret?) return secret;
    // Stored by an older version as an item of its own: move it in.
    return _moving[ref] ??= () async {
      try {
        final legacy = await _storage.read(key: ref);
        if (legacy != null) {
          await _save((vault) => vault[ref] = legacy);
          await _storage.delete(key: ref);
        }
        return legacy;
      } finally {
        _moving.remove(ref)?.ignore();
      }
    }();
  }

  Future<void> delete(String ref) async {
    await _save((vault) => vault.remove(ref));
    await _storage.delete(key: ref);
  }
}
