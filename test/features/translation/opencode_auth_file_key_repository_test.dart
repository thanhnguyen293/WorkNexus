import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/translation/data/datasources/opencode_auth_file.dart';
import 'package:work_nexus/features/translation/data/repositories/opencode_auth_file_key_repository.dart';
import 'package:work_nexus/features/translation/domain/value_objects/opencode_key_links.dart';

void main() {
  late Directory dir;
  late File authFile;
  late OpenCodeAuthFileKeyRepository repository;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('opencode_auth_test');
    authFile = File('${dir.path}/auth.json');
    repository = OpenCodeAuthFileKeyRepository(
      OpenCodeAuthFile(pathOverride: authFile.path),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  void writeAuth(Map<String, dynamic> entries) =>
      authFile.writeAsStringSync(jsonEncode(entries));

  test('an API key reads back masked; an OAuth login has no preview', () async {
    writeAuth({
      'opencode': {'type': 'api', 'key': 'sk-000011112222n5UT'},
      'anthropic': {'type': 'oauth', 'access': 'a', 'refresh': 'r'},
    });

    final api = (await repository.authFor('opencode')).valueOrNull!;
    final oauth = (await repository.authFor('anthropic')).valueOrNull!;
    final none = (await repository.authFor('groq')).valueOrNull!;

    expect(api.linked, isTrue);
    expect(api.keyPreview, '••••••n5UT');
    expect(oauth.linked, isTrue);
    expect(oauth.keyPreview, isNull);
    expect(none.linked, isFalse);
  });

  test('saving replaces one provider and keeps the other logins', () async {
    writeAuth({
      'opencode': {'type': 'api', 'key': 'old'},
      'anthropic': {'type': 'oauth', 'access': 'a'},
    });

    final result = await repository.saveApiKey(
      providerId: 'opencode',
      key: ' new-key ',
    );

    expect(result.isOk, isTrue);
    final stored = jsonDecode(authFile.readAsStringSync()) as Map;
    expect(stored['opencode'], {'type': 'api', 'key': 'new-key'});
    expect(stored['anthropic'], {'type': 'oauth', 'access': 'a'});
  });

  test('a first save creates the file', () async {
    await repository.saveApiKey(providerId: 'opencode', key: 'k');

    expect(authFile.existsSync(), isTrue);
  });

  test('a malformed file is left alone instead of overwritten', () async {
    authFile.writeAsStringSync('{not json');

    final result = await repository.saveApiKey(providerId: 'x', key: 'k');

    expect(result.failureOrNull, isA<ParseFailure>());
    expect(authFile.readAsStringSync(), '{not json');
  });

  test('the key belongs to the provider of the chosen model', () {
    expect(openCodeProviderOf('opencode/longcat-2.5-preview-free'), 'opencode');
    expect(openCodeProviderOf('anthropic/claude-x'), 'anthropic');
    expect(openCodeProviderOf(''), 'opencode');
    expect(openCodeKeyUrl('Google'), 'https://aistudio.google.com/apikey');
  });
}
