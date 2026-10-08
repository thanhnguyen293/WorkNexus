import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/opencode_credential.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/agents/data/datasources/opencode_auth_file.dart';
import 'package:work_nexus/features/agents/data/repositories/opencode_auth_file_repository.dart';

void main() {
  late Directory dir;
  late File authFile;
  late OpenCodeAuthFileRepository repository;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('opencode_auth_test');
    authFile = File('${dir.path}/auth.json');
    repository = OpenCodeAuthFileRepository(
      OpenCodeAuthFile(pathOverride: authFile.path),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  void writeAuth(Map<String, dynamic> entries) =>
      authFile.writeAsStringSync(jsonEncode(entries));

  Map<String, dynamic> readAuth() =>
      jsonDecode(authFile.readAsStringSync()) as Map<String, dynamic>;

  List<OpenCodeCredential> okValue(Result<List<OpenCodeCredential>> result) =>
      (result as Ok<List<OpenCodeCredential>>).value;

  group('listCredentials', () {
    test('reads entries sorted by provider, masking the API key', () async {
      writeAuth({
        'opencode-go': {'type': 'api', 'key': 'sk-live-000011112222a1b2'},
        'anthropic': {'type': 'oauth', 'access': 'token', 'refresh': 'token'},
      });

      final credentials = okValue(await repository.listCredentials());

      expect(credentials.map((c) => c.providerId), [
        'anthropic',
        'opencode-go',
      ]);
      expect(credentials.first.type, OpenCodeAuthType.oauth);
      expect(credentials.first.keyPreview, isNull);
      expect(credentials.last.type, OpenCodeAuthType.api);
      expect(credentials.last.keyPreview, '••••••a1b2');
    });

    test('a missing file reads as no credentials', () async {
      expect(okValue(await repository.listCredentials()), isEmpty);
    });

    test('an unrecognized auth type is reported rather than dropped', () async {
      writeAuth({
        'future': {'type': 'something-new'},
      });

      final credentials = okValue(await repository.listCredentials());

      expect(credentials.single.type, OpenCodeAuthType.unknown);
    });

    test('malformed JSON fails instead of reading as empty', () async {
      authFile.writeAsStringSync('{not json');

      final result = await repository.listCredentials();

      expect(result.failureOrNull, isA<ParseFailure>());
    });
  });

  group('saveApiKey', () {
    test('replaces one provider and leaves the others untouched', () async {
      writeAuth({
        'opencode-go': {'type': 'api', 'key': 'old-key'},
        'anthropic': {'type': 'oauth', 'access': 'token'},
      });

      final result = await repository.saveApiKey(
        providerId: 'opencode-go',
        key: 'new-key',
      );

      expect(result.isOk, isTrue);
      expect(readAuth()['opencode-go'], {'type': 'api', 'key': 'new-key'});
      expect(readAuth()['anthropic'], {'type': 'oauth', 'access': 'token'});
    });

    test('creates the file on first save', () async {
      final result = await repository.saveApiKey(
        providerId: 'opencode',
        key: 'first-key',
      );

      expect(result.isOk, isTrue);
      expect(readAuth(), {
        'opencode': {'type': 'api', 'key': 'first-key'},
      });
    });

    test('trims the provider and key before storing them', () async {
      await repository.saveApiKey(providerId: '  opencode  ', key: ' k \n');

      expect(readAuth(), {
        'opencode': {'type': 'api', 'key': 'k'},
      });
    });

    test('rejects a blank key without touching the file', () async {
      writeAuth({
        'opencode': {'type': 'api', 'key': 'keep-me'},
      });

      final result = await repository.saveApiKey(
        providerId: 'opencode',
        key: '   ',
      );

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(readAuth()['opencode'], {'type': 'api', 'key': 'keep-me'});
    });

    test('rejects a blank provider', () async {
      final result = await repository.saveApiKey(providerId: ' ', key: 'k');

      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test('refuses to overwrite a file it could not parse', () async {
      authFile.writeAsStringSync('{not json');

      final result = await repository.saveApiKey(
        providerId: 'opencode',
        key: 'new-key',
      );

      expect(result.failureOrNull, isA<ParseFailure>());
      expect(authFile.readAsStringSync(), '{not json');
    });
  });

  group('removeCredential', () {
    test('drops only the named provider', () async {
      writeAuth({
        'opencode': {'type': 'api', 'key': 'k'},
        'anthropic': {'type': 'oauth', 'access': 'token'},
      });

      final result = await repository.removeCredential('opencode');

      expect(result.isOk, isTrue);
      expect(readAuth().keys, ['anthropic']);
    });

    test('removing an unknown provider is a no-op success', () async {
      writeAuth({
        'opencode': {'type': 'api', 'key': 'k'},
      });

      final result = await repository.removeCredential('nope');

      expect(result.isOk, isTrue);
      expect(readAuth().keys, ['opencode']);
    });
  });
}
