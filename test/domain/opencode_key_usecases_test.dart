import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/opencode_credential.dart';
import 'package:work_nexus/core/domain/repositories/opencode_auth_repository.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/connections/domain/usecases/load_opencode_credentials.dart';
import 'package:work_nexus/features/connections/domain/usecases/remove_opencode_credential.dart';
import 'package:work_nexus/features/connections/domain/usecases/save_opencode_key.dart';

class _MockOpenCodeAuthRepository extends Mock
    implements OpenCodeAuthRepository {}

const _credential = OpenCodeCredential(
  providerId: 'opencode-go',
  type: OpenCodeAuthType.api,
  keyPreview: '••••••a1b2',
);

void main() {
  late _MockOpenCodeAuthRepository repository;

  setUp(() => repository = _MockOpenCodeAuthRepository());

  test('LoadOpenCodeCredentials returns the stored credentials', () async {
    when(() => repository.listCredentials())
        .thenAnswer((_) async => const Ok([_credential]));

    final result = await LoadOpenCodeCredentials(repository)();

    expect((result as Ok<List<OpenCodeCredential>>).value, [_credential]);
    verify(() => repository.listCredentials()).called(1);
  });

  test('LoadOpenCodeCredentials passes a read failure through', () async {
    when(() => repository.listCredentials())
        .thenAnswer((_) async => const Err(ParseFailure('bad json')));

    final result = await LoadOpenCodeCredentials(repository)();

    expect(result.failureOrNull, isA<ParseFailure>());
  });

  test('SaveOpenCodeKey forwards the provider and key', () async {
    when(() => repository.saveApiKey(providerId: 'opencode-go', key: 'new-key'))
        .thenAnswer((_) async => const Ok(null));

    final result = await SaveOpenCodeKey(repository)(
      providerId: 'opencode-go',
      key: 'new-key',
    );

    expect(result.isOk, isTrue);
    verify(
      () => repository.saveApiKey(providerId: 'opencode-go', key: 'new-key'),
    ).called(1);
  });

  test('SaveOpenCodeKey surfaces a write failure', () async {
    when(() => repository.saveApiKey(providerId: 'opencode-go', key: 'k'))
        .thenAnswer((_) async => const Err(StorageFailure('read-only file')));

    final result = await SaveOpenCodeKey(repository)(
      providerId: 'opencode-go',
      key: 'k',
    );

    expect(result.failureOrNull, isA<StorageFailure>());
  });

  test('RemoveOpenCodeCredential unlinks the named provider', () async {
    when(() => repository.removeCredential('opencode-go'))
        .thenAnswer((_) async => const Ok(null));

    final result = await RemoveOpenCodeCredential(repository)('opencode-go');

    expect(result.isOk, isTrue);
    verify(() => repository.removeCredential('opencode-go')).called(1);
  });
}
