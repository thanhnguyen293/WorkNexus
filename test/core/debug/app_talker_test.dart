import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/debug/app_talker.dart';

class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'status': 'success'}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test('maskUrlSecrets hides session ids and tokens, nothing else', () {
    final masked = maskUrlSecrets(
      Uri.parse(
        'https://z.example.com/zentao/bug-browse-1.json'
        '?zentaosid=abc123&private_token=t0k&keywords=login&page=2',
      ),
    );
    expect(masked.queryParameters, {
      'zentaosid': '***',
      'private_token': '***',
      'keywords': 'login',
      'page': '2',
    });
    expect(masked.toString(), isNot(contains('abc123')));

    final plain = Uri.parse('https://z.example.com/api.php/v1/tasks/7');
    expect(maskUrlSecrets(plain), same(plain));
  });

  test('a session id in the URL never reaches the in-app log', () async {
    appTalker.cleanHistory();
    final dio = Dio()
      ..httpClientAdapter = _OkAdapter()
      ..interceptors.add(buildTalkerDioLogger());

    await dio.get<dynamic>(
      'https://z.example.com/zentao/task-view-9.json',
      queryParameters: {'zentaosid': 'SECRET-SID'},
    );
    await dio.get<dynamic>('https://z.example.com/api.php/v1/tasks/9');

    final logged = appTalker.history
        .map((e) => e.generateTextMessage())
        .join('\n');
    expect(logged, isNot(contains('SECRET-SID')));
    // Still visible, masked.
    expect(logged, contains('task-view-9.json?zentaosid=***'));
    // Requests without a secret keep the regular request/response logs.
    expect(logged, contains('/api.php/v1/tasks/9'));
  });
}
