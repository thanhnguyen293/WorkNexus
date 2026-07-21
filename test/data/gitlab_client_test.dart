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

  test('paginated list requests use the shared 500 item page size', () async {
    final fake = _FakeAdapter((_) {
      return ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await _client(fake).projects();

    expect(fake.requests.single.uri.queryParameters['per_page'], '500');
  });

  test('my merge request feeds request assigned and review scopes', () async {
    final fake = _FakeAdapter((_) {
      return ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final client = _client(fake);

    await client.assignedMergeRequests();
    await client.reviewMergeRequests('alice');

    expect(fake.requests, hasLength(2));
    expect(fake.requests[0].uri.path, '/api/v4/merge_requests');
    expect(fake.requests[0].uri.queryParameters['scope'], 'assigned_to_me');
    expect(fake.requests[1].uri.path, '/api/v4/merge_requests');
    expect(fake.requests[1].uri.queryParameters['scope'], 'reviews_for_me');
    expect(
      fake.requests[1].uri.queryParameters.containsKey('reviewer_username'),
      isFalse,
    );
  });

  test('MR metadata mutations use GitLab 16.3 compatible payloads', () async {
    final fake = _FakeAdapter(
      (_) => ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final client = _client(fake);

    await client.updateMergeRequest(
      'group%2Fweb',
      '42',
      labels: const ['backend', 'review'],
      milestoneId: 12,
    );
    await client.setMergeRequestTimeEstimate('group%2Fweb', '42', '2h');
    await client.addMergeRequestSpentTime('group%2Fweb', '42', '30m');
    expect(fake.requests, hasLength(3));
    expect(fake.requests[0].method, 'PUT');
    expect(fake.requests[0].data, {
      'labels': 'backend,review',
      'milestone_id': 12,
    });
    expect(
      fake.requests[1].uri.path,
      '/api/v4/projects/group%2Fweb/merge_requests/42/time_estimate',
    );
    expect(fake.requests[1].data, {'duration': '2h'});
    expect(
      fake.requests[2].uri.path,
      '/api/v4/projects/group%2Fweb/merge_requests/42/add_spent_time',
    );
    expect(fake.requests[2].data, {'duration': '30m'});
  });

  test('MR metadata options use project label and milestone APIs', () async {
    final fake = _FakeAdapter((request) {
      final body = request.path.endsWith('/labels')
          ? '[{"name":"backend","color":"#428BCA"}]'
          : '[{"id":12,"iid":3,"title":"Release 1.0"}]';
      return ResponseBody.fromString(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final client = _client(fake);

    final labels = await client.projectLabels('group%2Fweb');
    final milestones = await client.projectMilestones('group%2Fweb');

    expect(labels.single.name, 'backend');
    expect(labels.single.color, '#428BCA');
    expect(milestones.single.title, 'Release 1.0');
    expect(fake.requests[1].uri.queryParameters['state'], 'active');
    expect(
      fake.requests[1].uri.queryParameters['include_parent_milestones'],
      'true',
    );
  });

  test(
    'review feed falls back to reviewer_username when scope is unsupported',
    () async {
      var calls = 0;
      final fake = _FakeAdapter((_) {
        calls++;
        if (calls == 1) {
          return ResponseBody.fromString(
            '{"error":"scope does not have a valid value"}',
            400,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '[]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await _client(fake).reviewMergeRequests('alice');

      expect(fake.requests, hasLength(2));
      expect(fake.requests[0].uri.queryParameters['scope'], 'reviews_for_me');
      expect(
        fake.requests[1].uri.queryParameters['reviewer_username'],
        'alice',
      );
      expect(
        fake.requests[1].uri.queryParameters.containsKey('scope'),
        isFalse,
      );
    },
  );

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
