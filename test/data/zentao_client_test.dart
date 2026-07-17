import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_adapter.dart';
import 'package:work_nexus/features/connections/data/zentao/zentao_client.dart';

/// A minimal ZenTao bug ticket for detail/comment fetches.
Ticket _bugTicket() => const Ticket(
  id: 'zt:4302',
  accountId: 'zt',
  projectId: 'zt:ERP',
  providerType: ProviderType.zentao,
  externalKey: '4302',
  externalType: 'Bug',
  title: 'stale',
  body: 'stale',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
);

/// A fake dio adapter that records requests and returns canned JSON.
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
    Future? cancelFuture,
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

ZenTaoClient _client(_FakeAdapter fake) {
  final dio = Dio()..httpClientAdapter = fake;
  return ZenTaoClient(
    baseUrl: 'https://zentao.example.com',
    account: 'me',
    password: 'pw',
    dio: dio,
  );
}

void main() {
  test('authenticate posts to /tokens and returns the account', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.path.endsWith('/tokens')) return _json({'token': 'tok123'});
      return _json({});
    });
    final account = await _client(fake).authenticate();
    expect(account, 'me');
    expect(fake.requests.single.uri.path, contains('/api.php/v1/tokens'));
  });

  test('v1 requests carry the Token header after auth', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.path.endsWith('/tokens')) return _json({'token': 'tok123'});
      return _json({'id': 1});
    });
    final client = _client(fake);
    await client.api.entity('bugs', '1');
    final getReq = fake.requests.firstWhere((r) => r.path.contains('bugs/1'));
    expect(getReq.headers['Token'], 'tok123');
  });

  test(
    'listAssignedTickets parses the v1 /user response into unified tickets',
    () async {
      final fake = _FakeAdapter((opts) {
        if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
        if (opts.uri.path.endsWith('/api.php/v1/user')) {
          return _json({
            'profile': {'account': 'me'},
            'bug': {
              'total': 1,
              'bugs': [
                {
                  'id': 1092,
                  'title': 'Inventory sync fails',
                  'status': 'active',
                  'confirmed': 1,
                  'pri': 1,
                  'assignedTo': 'me',
                  'productName': 'ERP',
                  'lastEditedDate': '2026-07-16 10:00:00',
                },
              ],
            },
            'task': {'total': 0, 'tasks': []},
            'story': {'total': 0, 'stories': []},
          });
        }
        return _json(const {});
      });

      final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
      final res = await adapter.listAssignedTickets();

      expect(res, isA<Ok>());
      final tickets = (res as Ok).value.tickets;
      expect(tickets.length, 1);
      final t = tickets.single;
      expect(t.providerType, ProviderType.zentao);
      expect(t.externalKey, '1092');
      expect(t.externalType, 'Bug');
      expect(t.status, UnifiedStatus.todo); // active + confirmed
      expect(t.title, 'Inventory sync fails');
      expect(t.url, 'https://zentao.example.com/bug-view-1092.html');
    },
  );

  test(
    'listAssignedTickets pages through the /user total (no drops)',
    () async {
      final fake = _FakeAdapter((opts) {
        if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
        if (opts.uri.path.endsWith('/api.php/v1/user')) {
          final fields = opts.uri.queryParameters['fields'];
          final page = opts.uri.queryParameters['page'];
          if (fields == 'bug') {
            // total = 2, but the server hands out one bug per page.
            final id = page == '1' ? 1871 : 3259;
            return _json({
              'bug': {
                'total': 2,
                'bugs': [
                  {'id': id, 'title': 'Bug $id', 'status': 'active', 'pri': 2},
                ],
              },
            });
          }
          return _json({
            'task': {'total': 0, 'tasks': []},
          });
        }
        return _json(const {});
      });

      final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
      final res = await adapter.listAssignedTickets();

      expect(res, isA<Ok>());
      final tickets = (res as Ok).value.tickets;
      expect(tickets.map((t) => t.externalKey).toSet(), {'1871', '3259'});
    },
  );

  test(
    'getTicket fetches v1 detail and converts HTML steps to Markdown',
    () async {
      final fake = _FakeAdapter((opts) {
        if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
        if (opts.uri.path.endsWith('/api.php/v1/bugs/4302')) {
          return _json({
            'id': 4302,
            'title': 'Login loops',
            'status': 'resolved',
            'pri': 2,
            'steps':
                '<p>Open <strong>login</strong></p><ol><li>step one</li></ol>',
            'productName': 'ERP',
          });
        }
        return _json(const {});
      });

      final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
      final res = await adapter.getTicket(_bugTicket());

      expect(res, isA<Ok>());
      final t = (res as Ok).value as Ticket;
      expect(t.title, 'Login loops');
      expect(t.status, UnifiedStatus.review); // resolved → review
      // HTML became Markdown: bold + ordered list.
      expect(t.body, contains('**login**'));
      expect(t.body, contains('step one'));
      expect(t.body, isNot(contains('<')));
    },
  );

  test('assignTicket POSTs assignedTo to /{type}/{id}/assignTo', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return _json({'status': 'success'});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.assignTicket(
      _bugTicket(),
      assignee: 'thanh',
      comment: 'please',
    );

    expect(res, isA<Ok>());
    final req = fake.requests.firstWhere(
      (r) => r.path.contains('bugs/4302/assignTo'),
    );
    expect(req.method, 'POST');
    expect((req.data as Map)['assignedTo'], 'thanh');
    expect((req.data as Map)['comment'], 'please');
  });

  test(
    'resolveBug POSTs resolution + default build to /bugs/{id}/resolve',
    () async {
      final fake = _FakeAdapter((opts) {
        if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
        return _json({'status': 'success'});
      });
      final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
      final res = await adapter.resolveBug(_bugTicket(), resolution: 'fixed');

      expect(res, isA<Ok>());
      final req = fake.requests.firstWhere(
        (r) => r.path.contains('bugs/4302/resolve'),
      );
      expect(req.method, 'POST');
      expect((req.data as Map)['resolution'], 'fixed');
      expect((req.data as Map)['resolvedBuild'], 'trunk');
      expect((req.data as Map).containsKey('resolvedDate'), isTrue);
    },
  );

  test('listUsers parses /users into sorted ProviderUsers', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/users')) {
        return _json({
          'total': 2,
          'users': [
            {'account': 'zoe', 'realname': 'Zoe'},
            {'account': 'amy', 'realname': 'Amy'},
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listUsers();

    expect(res, isA<Ok>());
    final users = (res as Ok).value;
    expect(users.map((u) => u.displayName).toList(), ['Amy', 'Zoe']); // sorted
    expect(users.first.account, 'amy');
  });

  test('listComments parses actions given as an id-keyed object', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/bugs/4302')) {
        return _json({
          'id': 4302,
          'title': 'Login loops',
          'status': 'active',
          // ZenTao often returns `actions` as an object keyed by action id.
          'actions': {
            '2': {
              'id': 2,
              'action': 'commented',
              'actor': {'account': 'thanh', 'realname': 'Thanh'},
              'comment': '<p>Fixed in <code>auth.dart</code></p>',
              'date': '2026-07-16 09:00:00',
            },
            '1': {
              'id': 1,
              'action': 'opened',
              'actor': 'system',
              'comment': '',
              'date': '2026-07-15 08:00:00',
            },
          },
        });
      }
      return _json(const {});
    });

    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listComments(_bugTicket());

    expect(res, isA<Ok>());
    final comments = (res as Ok).value;
    // Only the `commented` action becomes a comment (the empty 'opened' drops).
    expect(comments.length, 1);
    expect(comments.single.authorName, 'Thanh');
    expect(comments.single.body, contains('`auth.dart`'));
  });
}
