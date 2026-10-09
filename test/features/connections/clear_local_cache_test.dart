import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/connections/domain/entities/cache_section.dart';
import 'package:work_nexus/features/connections/domain/repositories/local_cache_repository.dart';
import 'package:work_nexus/features/connections/domain/usecases/clear_local_cache.dart';

class _MockRepository extends Mock implements LocalCacheRepository {}

void main() {
  late _MockRepository repository;
  late ClearLocalCache clear;

  setUpAll(() => registerFallbackValue(<CacheSection>{}));

  setUp(() {
    repository = _MockRepository();
    clear = ClearLocalCache(repository);
  });

  test('passes the picked sections to the repository', () async {
    when(() => repository.clear(any())).thenAnswer((_) async => const Ok(null));

    final result = await clear({CacheSection.chat});

    expect(result, isA<Ok<void>>());
    verify(() => repository.clear({CacheSection.chat})).called(1);
  });

  test('nothing picked clears nothing', () async {
    final result = await clear({});

    expect(result, isA<Ok<void>>());
    verifyNever(() => repository.clear(any()));
  });
}
