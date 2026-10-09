import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores provider secrets (passwords/tokens) in the OS keychain. The drift DB
/// only ever holds a `credentialsRef` key into this store — never the secret.
///
/// On macOS we disable the data-protection keychain: it requires a signed
/// `keychain-access-groups` entitlement (only present with a real dev-team
/// signing identity), so ad-hoc/local builds hit `-34018 errSecMissingEntitlement`.
/// The legacy login keychain needs no such entitlement.
///
/// Reads are cached for the app's lifetime: every keychain read of an item can
/// raise a macOS "allow access" prompt (each rebuild of an ad-hoc signed app
/// counts as a new app, so "Always Allow" does not stick), and sync, chat and
/// link cards all read the same secrets — often at the same moment.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The legacy file-based keychain (v9's default; v11 defaults to
            // the data-protection keychain), so existing items are still found.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  static String refFor(String accountId) => 'secret:$accountId';

  /// Secrets read or written so far, or the read still in flight, by ref.
  final Map<String, Future<String?>> _cache = {};

  Future<void> write(String ref, String secret) async {
    await _storage.write(key: ref, value: secret);
    _cache[ref] = Future.value(secret);
  }

  Future<String?> read(String ref) => _cache.putIfAbsent(ref, () async {
    try {
      return await _storage.read(key: ref);
    } catch (_) {
      // A denied or failed read is asked again next time, not remembered.
      _cache.remove(ref)?.ignore();
      rethrow;
    }
  });

  Future<void> delete(String ref) async {
    _cache.remove(ref)?.ignore();
    await _storage.delete(key: ref);
  }
}
