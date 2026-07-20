import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_client.dart';

/// A fake dio adapter that records requests and returns a canned response.
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

ResponseBody _image(List<int> bytes) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    Headers.contentTypeHeader: ['image/png'],
  },
);

ResponseBody _html() => ResponseBody.fromString(
  '<html>sign in</html>',
  200,
  headers: {
    Headers.contentTypeHeader: ['text/html; charset=utf-8'],
  },
);

GitLabClient _client(_FakeAdapter fake) {
  final dio = Dio()..httpClientAdapter = fake;
  return GitLabClient(
    baseUrl: 'https://gitlab.example.com',
    token: 'pat123',
    dio: dio,
  );
}

void main() {
  // PNG magic bytes — enough to stand in for real image data.
  const png = [0x89, 0x50, 0x4e, 0x47];

  test(
    'fetchBytes routes a bare /uploads link to the markdown uploads API with the PAT',
    () async {
      final fake = _FakeAdapter((_) => _image(png));
      final client = _client(fake);

      final bytes = await client.fetchBytes(
        '/uploads/11043117eeafd1cd26d74dbdcf8279a0/pasted_image_1778757174593.png',
        projectPath: 'root/tbchat',
        projectId: 42,
      );

      expect(bytes, orderedEquals(png));
      final req = fake.requests.single;
      // The numeric project id is preferred, on the PAT-readable API endpoint —
      // NOT the web `/root/tbchat/uploads/…` path (which needs a session cookie).
      expect(
        req.uri.path,
        '/api/v4/projects/42/uploads/11043117eeafd1cd26d74dbdcf8279a0/'
        'pasted_image_1778757174593.png',
      );
      expect(req.headers['PRIVATE-TOKEN'], 'pat123');
    },
  );

  test(
    'fetchBytes falls back to the URL-encoded project path when no id is known',
    () async {
      final fake = _FakeAdapter((_) => _image(png));

      await _client(
        fake,
      ).fetchBytes('/uploads/abc123/img.png', projectPath: 'group/web');

      // `group/web` is a single, percent-encoded path segment (`group%2Fweb`).
      expect(
        fake.requests.single.uri.toString(),
        'https://gitlab.example.com/api/v4/projects/group%2Fweb/uploads/'
        'abc123/img.png',
      );
    },
  );

  test(
    'fetchBytes returns null for a non-image (login/HTML) response',
    () async {
      final fake = _FakeAdapter((_) => _html());

      final bytes = await _client(
        fake,
      ).fetchBytes('/uploads/abc123/img.png', projectId: 42);

      expect(bytes, isNull);
    },
  );

  test(
    'fetchBytes fetches an absolute image URL as-is, without the PAT',
    () async {
      final fake = _FakeAdapter((_) => _image(png));

      await _client(
        fake,
      ).fetchBytes('https://cdn.example.com/pic.png', projectId: 42);

      final req = fake.requests.single;
      expect(req.uri.toString(), 'https://cdn.example.com/pic.png');
      // The PAT must never leak to a third-party host.
      expect(req.headers.containsKey('PRIVATE-TOKEN'), isFalse);
    },
  );
}
