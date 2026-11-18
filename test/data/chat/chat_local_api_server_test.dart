import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_api_server.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_local_api.dart';

/// The localhost endpoint local AI tools use chat through: only with the
/// token from the discovery file, never from a browser, and only while
/// running.
void main() {
  late Directory dir;
  late ChatLocalApiServer server;
  late List<Map<String, Object?>> sent;
  late Result<void> nextResult;
  late List<Map<String, Object?>> calls;
  late Result<ChatHistoryStep> nextStep;
  late Result<ChatAttachmentFile> nextFile;

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

  Future<Result<ChatHistoryStep>> loadOlder({
    required String accountId,
    required String chatGid,
    required int pageSize,
  }) async {
    calls.add({
      'accountId': accountId,
      'chatGid': chatGid,
      'pageSize': pageSize,
    });
    return nextStep;
  }

  Future<Result<ChatAttachmentFile>> attachment({
    required String accountId,
    required String chatGid,
    required int messageId,
  }) async {
    calls.add({
      'accountId': accountId,
      'chatGid': chatGid,
      'messageId': messageId,
    });
    return nextFile;
  }

  ChatLocalApiHandlers handlers() => ChatLocalApiHandlers(
    send: send,
    loadOlder: loadOlder,
    attachment: attachment,
  );

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
    calls = [];
    nextStep = const Ok((loaded: 0, reachesStart: true));
    nextFile = const Err(NotFoundFailure('none'));
    server = ChatLocalApiServer(directory: () async => dir);
    await server.start(handlers());
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
      await server.start(handlers());
      expect((await readDiscovery())['token'], isNot(first));
    },
  );

  test('loads one older page, 100 messages unless asked', () async {
    final token = (await readDiscovery())['token']! as String;
    nextStep = const Ok((loaded: 80, reachesStart: false));
    final (status, body) = await call(
      'POST',
      '/v1/chat/load-older',
      token: token,
      body: {'accountId': 'a', 'chatGid': 'g'},
    );
    expect(status, HttpStatus.ok);
    expect(body, {'ok': true, 'loaded': 80, 'reachesStart': false});
    expect(calls.single, {'accountId': 'a', 'chatGid': 'g', 'pageSize': 100});
    expect(
      (await call(
        'POST',
        '/v1/chat/load-older',
        token: token,
        body: {'accountId': 'a', 'chatGid': 'g', 'pageSize': 0},
      )).$1,
      HttpStatus.badRequest,
    );
  });

  test('returns where an attachment was downloaded to', () async {
    final token = (await readDiscovery())['token']! as String;
    nextFile = const Ok((
      path: '/cache/a.png',
      name: 'a.png',
      size: 12,
      mimeType: 'image/png',
      isImage: true,
    ));
    final (status, body) = await call(
      'POST',
      '/v1/chat/attachment',
      token: token,
      body: {'accountId': 'a', 'chatGid': 'g', 'messageId': 7},
    );
    expect(status, HttpStatus.ok);
    expect(body, {
      'ok': true,
      'path': '/cache/a.png',
      'name': 'a.png',
      'size': 12,
      'mimeType': 'image/png',
      'isImage': true,
    });
    expect(calls.single['messageId'], 7);
  });

  test('maps attachment failures to 404 / 400 / 502', () async {
    final token = (await readDiscovery())['token']! as String;
    Future<int> status() async => (await call(
      'POST',
      '/v1/chat/attachment',
      token: token,
      body: {'accountId': 'a', 'chatGid': 'g', 'messageId': 7},
    )).$1;
    nextFile = const Err(NotFoundFailure('gone'));
    expect(await status(), HttpStatus.notFound);
    nextFile = const Err(ValidationFailure('no file'));
    expect(await status(), HttpStatus.badRequest);
    nextFile = const Err(NetworkFailure('offline'));
    expect(await status(), HttpStatus.badGateway);
    expect(
      (await call(
        'POST',
        '/v1/chat/attachment',
        token: token,
        body: {'accountId': 'a', 'chatGid': 'g', 'messageId': '7'},
      )).$1,
      HttpStatus.badRequest,
    );
  });
}
