import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_api_server.dart';

/// The localhost endpoint local AI tools send chat messages through: only
/// with the token from the discovery file, never from a browser, and only
/// while running.
void main() {
  late Directory dir;
  late ChatLocalApiServer server;
  late List<Map<String, Object?>> sent;
  late Result<void> nextResult;

  Future<Result<void>> send({
    required String accountId,
    required String chatGid,
    required String text,
    required bool markdown,
  }) async {
    sent.add({
      'accountId': accountId,
      'chatGid': chatGid,
      'text': text,
      'markdown': markdown,
    });
    return nextResult;
  }

  File discovery() =>
      File('${dir.path}/${ChatLocalApiServer.discoveryFileName}');

  Future<Map<String, Object?>> readDiscovery() async =>
      jsonDecode(await discovery().readAsString()) as Map<String, Object?>;

  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    final info = await readDiscovery();
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.open(
      method,
      InternetAddress.loopbackIPv4.address,
      info['port']! as int,
      path,
    );
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    headers.forEach(request.headers.set);
    if (body != null) {
      request.write(body is String ? body : jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return (response.statusCode, jsonDecode(text) as Map<String, Object?>);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wn_local_api');
    sent = [];
    nextResult = const Ok(null);
    server = ChatLocalApiServer(directory: () async => dir);
    await server.start(send);
  });

  tearDown(() async {
    await server.stop();
    await dir.delete(recursive: true);
  });

  test('writes its port and a token only the user can read', () async {
    final info = await readDiscovery();
    expect(info['version'], 1);
    expect(info['port'], isA<int>());
    expect((info['token']! as String).length, greaterThanOrEqualTo(40));
    if (!Platform.isWindows) {
      final mode = (await discovery().stat()).mode & 0x1ff;
      expect(mode, 0x180, reason: 'expected 0600');
    }
  });

  test('sends a message with the right token', () async {
    final token = (await readDiscovery())['token']! as String;
    final (status, body) = await call(
      'POST',
      '/v1/chat/send',
      token: token,
      body: {'accountId': 'zt-1', 'chatGid': '40&40', 'text': 'hi'},
    );
    expect(status, HttpStatus.ok);
    expect(body, {'ok': true});
    expect(sent, [
      {
        'accountId': 'zt-1',
        'chatGid': '40&40',
        'text': 'hi',
        'markdown': false,
      },
    ]);
  });

  test('passes on a send failure as 502 with its message', () async {
    nextResult = const Err(NetworkFailure('Chat is offline'));
    final token = (await readDiscovery())['token']! as String;
    final (status, body) = await call(
      'POST',
      '/v1/chat/send',
      token: token,
      body: {'accountId': 'a', 'chatGid': 'g', 'text': 't', 'markdown': true},
    );
    expect(status, HttpStatus.badGateway);
    expect(body['error'], 'Chat is offline');
    expect(sent.single['markdown'], isTrue);
  });

  test('refuses a missing or wrong token', () async {
    final payload = {'accountId': 'a', 'chatGid': 'g', 'text': 't'};
    expect(
      (await call('POST', '/v1/chat/send', body: payload)).$1,
      HttpStatus.unauthorized,
    );
    expect(
      (await call('POST', '/v1/chat/send', token: 'nope', body: payload)).$1,
      HttpStatus.unauthorized,
    );
    expect(sent, isEmpty);
  });

  test('refuses browser requests even with the token', () async {
    final token = (await readDiscovery())['token']! as String;
    final (status, _) = await call(
      'POST',
      '/v1/chat/send',
      token: token,
      headers: {'origin': 'https://example.com'},
      body: {'accountId': 'a', 'chatGid': 'g', 'text': 't'},
    );
    expect(status, HttpStatus.forbidden);
    expect(sent, isEmpty);
  });

  test('rejects malformed, oversized and unknown requests', () async {
    final token = (await readDiscovery())['token']! as String;
    expect(
      (await call('POST', '/v1/chat/send', token: token, body: '{oops')).$1,
      HttpStatus.badRequest,
    );
    expect(
      (await call(
        'POST',
        '/v1/chat/send',
        token: token,
        body: {'chatGid': 'g', 'text': 't'},
      )).$1,
      HttpStatus.badRequest,
    );
    expect(
      (await call(
        'POST',
        '/v1/chat/send',
        token: token,
        body: {'accountId': 'a', 'chatGid': 'g', 'text': 'x' * 70000},
      )).$1,
      HttpStatus.requestEntityTooLarge,
    );
    expect(
      (await call('GET', '/v1/chat/send', token: token)).$1,
      HttpStatus.notFound,
    );
    expect((await call('GET', '/v1/health', token: token)).$1, HttpStatus.ok);
    expect(sent, isEmpty);
  });

  test(
    'stopping removes the discovery file; a restart gets a new token',
    () async {
      final first = (await readDiscovery())['token'];
      await server.stop();
      expect(await discovery().exists(), isFalse);
      await server.start(send);
      expect((await readDiscovery())['token'], isNot(first));
    },
  );
}
