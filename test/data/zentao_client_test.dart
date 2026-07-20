import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
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

  // The write actions use the classic `index.php` channel — this ZenTao build
  // has no `/bugs/{id}/<action>` REST endpoints (they 404).

  test('assignTicket POSTs to the classic {type}-assignTo action', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return _json({'result': 'success'});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.assignTicket(
      _bugTicket(),
      assignee: 'thanh',
      comment: 'please',
    );

    expect(res, isA<Ok<bool>>());
    final req = fake.requests.firstWhere(
      (r) => r.path.contains('bug-assignTo-4302'),
    );
    expect(req.method, 'POST');
    expect((req.data as Map)['assignedTo'], 'thanh');
    expect((req.data as Map)['comment'], 'please');
  });

  test('resolveBug POSTs resolution + default build to bug-resolve', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return _json({'result': 'success'});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.resolveBug(_bugTicket(), resolution: 'fixed');

    expect(res, isA<Ok<bool>>());
    final req = fake.requests.firstWhere(
      (r) => r.path.contains('bug-resolve-4302'),
    );
    expect(req.method, 'POST');
    expect((req.data as Map)['resolution'], 'fixed');
    expect((req.data as Map)['resolvedBuild'], 'trunk');
    expect((req.data as Map).containsKey('resolvedDate'), isTrue);
  });

  test('activateBug POSTs default openedBuild to bug-activate', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return _json({'result': 'success'});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.activateBug(_bugTicket());

    expect(res, isA<Ok<bool>>());
    final req = fake.requests.firstWhere(
      (r) => r.path.contains('bug-activate-4302'),
    );
    expect(req.method, 'POST');
    // ZenTao wants openedBuild as a non-empty string (not an array).
    expect((req.data as Map)['openedBuild'], 'trunk');
  });

  test('confirmBug POSTs to the classic bug-confirmBug action', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return _json({'result': 'success'});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.confirmBug(_bugTicket());

    expect(res, isA<Ok<bool>>());
    // This ZenTao build has no REST bug-action endpoints, so confirm uses the
    // classic index.php action and keeps the bug on the acting user (client
    // account) so a confirmed bug stays on their board.
    final req = fake.requests.firstWhere(
      (r) => r.path.contains('bug-confirmBug-4302'),
    );
    expect(req.method, 'POST');
    expect((req.data as Map)['assignedTo'], 'me');
  });

  test('confirmBug fails loudly when ZenTao returns HTML, not JSON', () async {
    // A POST ZenTao did not process comes back as the action page's HTML (or a
    // login redirect); that must surface as a failure, not a silent success.
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      return ResponseBody.fromString(
        '<!DOCTYPE html><html><body>login</body></html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.confirmBug(_bugTicket());

    expect(res, isA<Err<bool>>());
  });

  test(
    'classic actions carry site Origin/Referer + a uid (ZenTao CSRF)',
    () async {
      // ZenTao rejects state-changing POSTs whose Origin/Referer host doesn't
      // match the site; the web client also sends a form uid. Without these the
      // action silently bounced to the login page.
      final fake = _FakeAdapter((opts) {
        if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
        return _json({'result': 'success'});
      });
      final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
      await adapter.confirmBug(_bugTicket());

      final req = fake.requests.firstWhere(
        (r) => r.path.contains('bug-confirmBug-4302'),
      );
      final headers = req.headers.map(
        (k, v) => MapEntry(k.toLowerCase(), '$v'),
      );
      expect(headers['origin'], 'https://zentao.example.com');
      expect(headers['referer'], 'https://zentao.example.com/index.html');
      expect((req.data as Map).containsKey('uid'), isTrue);
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

  test('listProducts parses /products into provider products', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/products')) {
        return _json({
          'total': 2,
          'products': [
            {'id': 8, 'name': 'VN_Socialfi'},
            {'id': 9, 'name': 'VN_IM_Chat'},
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listProducts();

    expect(res, isA<Ok>());
    final products = (res as Ok).value;
    expect(products.map((p) => p.id).toList(), ['8', '9']);
    expect(products.map((p) => p.name).toList(), ['VN_Socialfi', 'VN_IM_Chat']);
  });

  test('listProductBugs fetches all bugs for a ZenTao product', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/products/8/bugs')) {
        return _json({
          'total': 1,
          'bugs': [
            {
              'id': 1092,
              'title': 'Product bug',
              'status': 'active',
              'confirmed': 1,
              'pri': 2,
              'productName': 'VN_Socialfi',
            },
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listProductBugs('8');

    expect(res, isA<Ok<TicketPage>>());
    final tickets = (res as Ok<TicketPage>).value.tickets;
    expect(tickets.single.externalKey, '1092');
    expect(tickets.single.labels, contains('zentao-product:8'));
    final req = fake.requests.firstWhere(
      (r) => r.uri.path.endsWith('/api.php/v1/products/8/bugs'),
    );
    expect(req.uri.queryParameters['page'], '1');
    expect(req.uri.queryParameters['limit'], '100');
  });

  test('listProjects parses /projects into provider projects', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/projects')) {
        return _json({
          'total': 2,
          'projects': [
            {'id': 3, 'name': 'Mobile App'},
            {'id': 4, 'name': 'Backend API'},
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listProjects();

    expect(res, isA<Ok<List<ProviderProject>>>());
    final projects = (res as Ok<List<ProviderProject>>).value;
    expect(projects.map((p) => p.id).toList(), ['3', '4']);
    expect(projects.map((p) => p.name).toList(), ['Mobile App', 'Backend API']);
  });

  test('listProjectExecutions parses /projects/{id}/executions', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/projects/3/executions')) {
        return _json({
          'total': 2,
          'executions': [
            {'id': 12, 'name': 'Sprint 12'},
            {'id': 11, 'name': 'Sprint 11'},
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listProjectExecutions('3');

    expect(res, isA<Ok<List<ProviderExecution>>>());
    final executions = (res as Ok<List<ProviderExecution>>).value;
    expect(executions.map((e) => e.id).toList(), ['12', '11']);
    expect(executions.every((e) => e.projectId == '3'), isTrue);
  });

  test('listExecutionTasks tags tasks with the execution label', () async {
    final fake = _FakeAdapter((opts) {
      if (opts.uri.path.endsWith('/tokens')) return _json({'token': 't'});
      if (opts.uri.path.endsWith('/api.php/v1/executions/12/tasks')) {
        return _json({
          'total': 1,
          'tasks': [
            {
              'id': 8801,
              'name': 'Wire the task board',
              'status': 'doing',
              'pri': 1,
            },
          ],
        });
      }
      return _json(const {});
    });
    final adapter = ZenTaoAdapter(accountId: 'zt', client: _client(fake));
    final res = await adapter.listExecutionTasks('12');

    expect(res, isA<Ok<TicketPage>>());
    final tickets = (res as Ok<TicketPage>).value.tickets;
    expect(tickets.single.externalKey, '8801');
    expect(tickets.single.externalType, 'Task');
    expect(tickets.single.labels, contains('zentao-execution:12'));
    final req = fake.requests.firstWhere(
      (r) => r.uri.path.endsWith('/api.php/v1/executions/12/tasks'),
    );
    expect(req.uri.queryParameters['page'], '1');
    expect(req.uri.queryParameters['limit'], '100');
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
