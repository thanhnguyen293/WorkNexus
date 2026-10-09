import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/credential_store.dart';

/// An in-memory keychain that counts reads per item (each would be a macOS
/// "allow access" prompt for an ad-hoc signed build).
class _FakeKeychain implements FlutterSecureStorage {
  final items = <String, String>{};
  final reads = <String, int>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads[key] = (reads[key] ?? 0) + 1;
    return items[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      items.remove(key);
    } else {
      items[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => items.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeKeychain keychain;

  setUp(() => keychain = _FakeKeychain());

  test('every secret lives in one item, read once per launch', () async {
    final first = CredentialStore(keychain);
    await first.write('secret:a', 'pw-a');
    await first.write('secret:b', 'pw-b');
    expect(keychain.items.keys, [CredentialStore.vaultKey]);

    // Next launch: three reads of two secrets, one keychain read.
    keychain.reads.clear();
    final next = CredentialStore(keychain);
    final secrets = await Future.wait([
      next.read('secret:a'),
      next.read('secret:b'),
      next.read('secret:a'),
    ]);
    expect(secrets, ['pw-a', 'pw-b', 'pw-a']);
    expect(keychain.reads, {CredentialStore.vaultKey: 1});
  });

  test('an older per-account item moves into the vault once', () async {
    keychain.items['secret:old'] = 'pw-old';
    final store = CredentialStore(keychain);

    final both = await Future.wait([
      store.read('secret:old'),
      store.read('secret:old'),
    ]);
    expect(both, ['pw-old', 'pw-old']);
    expect(keychain.reads['secret:old'], 1);
    expect(keychain.items.containsKey('secret:old'), isFalse);
    expect(jsonDecode(keychain.items[CredentialStore.vaultKey]!), {
      'secret:old': 'pw-old',
    });
  });

  test('a deleted secret is gone, others stay', () async {
    final store = CredentialStore(keychain);
    await store.write('secret:a', 'pw-a');
    await store.write('secret:b', 'pw-b');
    await store.delete('secret:a');

    final next = CredentialStore(keychain);
    expect(await next.read('secret:a'), isNull);
    expect(await next.read('secret:b'), 'pw-b');
  });
}
