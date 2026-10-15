import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/gitlab/data/datasources/gitlab_client.dart';

/// A fake dio adapter that records requests and answers from [handler].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

GitLabClient _client(_FakeAdapter fake) => GitLabClient(
  baseUrl: 'https://gitlab.example.com',
  token: 'pat123',
  dio: Dio()..httpClientAdapter = fake,
);

void main() {
  test('the current user is fetched once per client', () async {
    final fake = _FakeAdapter((_) => _json('{"id": 7, "username": "me"}'));
    final client = _client(fake);

    final first = await client.currentUser();
    final again = await client.currentUser();

    expect(first.username, 'me');
    expect(again.username, 'me');
    expect(fake.requests, hasLength(1));
  });

  test('a failed lookup is asked again', () async {
    var calls = 0;
    final fake = _FakeAdapter(
      (_) => ++calls == 1
          ? _json('{"message": "down"}', status: 503)
          : _json('{"id": 7, "username": "me"}'),
    );
    final client = _client(fake);

    await expectLater(client.currentUser(), throwsA(isA<DioException>()));
    expect((await client.currentUser()).username, 'me');
    expect(fake.requests, hasLength(2));
  });
}
