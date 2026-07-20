import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/connections/data/github/github_client.dart';

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

ResponseBody _json(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

GitHubClient _client(_FakeAdapter fake) {
  final dio = Dio()..httpClientAdapter = fake;
  return GitHubClient(baseUrl: 'https://github.com', token: 'pat', dio: dio);
}

void main() {
  test('paginated list requests use the shared 500 item page size', () async {
    final fake = _FakeAdapter((_) => _json(const []));

    await _client(fake).repos();

    expect(fake.requests.single.uri.queryParameters['per_page'], '500');
  });
}
