import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/platform/credential_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late CredentialStore store;

  setUp(() {
    storage = _MockStorage();
    store = CredentialStore(storage);
  });

  test(
    'reads a secret from the keychain once, even when asked at once',
    () async {
      when(() => storage.read(key: 'a')).thenAnswer((_) async => 's');
      final results = await Future.wait([store.read('a'), store.read('a')]);
      expect(await store.read('a'), 's');
      expect(results, ['s', 's']);
      verify(() => storage.read(key: 'a')).called(1);
    },
  );

  test('a written secret is served without reading it back', () async {
    when(() => storage.write(key: 'a', value: 'new')).thenAnswer((_) async {});
    await store.write('a', 'new');
    expect(await store.read('a'), 'new');
    verifyNever(() => storage.read(key: 'a'));
  });

  test('a failed read is retried, a deleted secret is read again', () async {
    var calls = 0;
    when(() => storage.read(key: 'a')).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('denied');
      return 's';
    });
    when(() => storage.delete(key: 'a')).thenAnswer((_) async {});
    await expectLater(store.read('a'), throwsException);
    expect(await store.read('a'), 's');
    await store.delete('a');
    await store.read('a');
    verify(() => storage.read(key: 'a')).called(3);
  });
}
