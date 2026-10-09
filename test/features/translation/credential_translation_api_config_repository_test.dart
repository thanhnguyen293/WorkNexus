import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/credential_store.dart';
import 'package:work_nexus/features/translation/data/repositories/credential_translation_api_config_repository.dart';
import 'package:work_nexus/features/translation/domain/entities/translation_api_config.dart';

class _CountingStore extends CredentialStore {
  final Map<String, String> values = {};
  var reads = 0;

  @override
  Future<String?> read(String ref) async {
    reads++;
    return values[ref];
  }

  @override
  Future<void> write(String ref, String secret) async => values[ref] = secret;

  @override
  Future<void> delete(String ref) async => values.remove(ref);
}

void main() {
  const config = TranslationApiConfig(
    presetId: 'groq',
    baseUrl: 'https://api.example.test/v1',
    model: 'm',
    apiKey: 'k',
  );

  test(
    'the stored configuration is read once, not on every translation',
    () async {
      final store = _CountingStore();
      final repo = CredentialTranslationApiConfigRepository(store);
      await repo.save(config);

      await repo.load();
      await repo.load();
      final loaded = (await repo.load()).valueOrNull;

      expect(loaded?.model, 'm');
      expect(store.reads, 0, reason: 'save primes the cache');
    },
  );

  test('clear and save are seen by the next load', () async {
    final store = _CountingStore();
    final repo = CredentialTranslationApiConfigRepository(store);
    expect((await repo.load()).valueOrNull, isNull);
    expect(store.reads, 1);

    await repo.save(config);
    expect((await repo.load()).valueOrNull?.apiKey, 'k');
    await repo.clear();
    expect((await repo.load()).valueOrNull, isNull);
  });
}
