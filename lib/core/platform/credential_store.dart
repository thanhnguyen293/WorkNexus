import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores provider secrets (passwords/tokens) in the OS keychain. The drift DB
/// only ever holds a `credentialsRef` key into this store — never the secret.
///
/// On macOS we disable the data-protection keychain: it requires a signed
/// `keychain-access-groups` entitlement (only present with a real dev-team
/// signing identity), so ad-hoc/local builds hit `-34018 errSecMissingEntitlement`.
/// The legacy login keychain needs no such entitlement.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  final FlutterSecureStorage _storage;

  static String refFor(String accountId) => 'secret:$accountId';

  Future<void> write(String ref, String secret) =>
      _storage.write(key: ref, value: secret);

  Future<String?> read(String ref) => _storage.read(key: ref);

  Future<void> delete(String ref) => _storage.delete(key: ref);
}
