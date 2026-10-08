import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_connection.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_connection_state.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_packet.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_server_info.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_signing.dart';

import 'support/fake_xxd_server.dart';

void main() {
  final credentials = XxdCredentials(
    server: Uri.parse('https://chat.test:11443'),
    account: 'demo',
    password: 'secret',
  );

  late FakeXxdServer server;
  late FakeXxdHttp http;
  late XxdConnection connection;

  XxdConnection connect({
    Duration ping = const Duration(minutes: 5),
    Duration timeout = const Duration(seconds: 2),
  }) => connection = XxdConnection(
    credentials: credentials,
    http: http,
    connector: server.connect,
    pingInterval: ping,
    requestTimeout: timeout,
    backoff: (_) => const Duration(milliseconds: 10),
  );

  Future<T> waitForState<T extends XxdConnectionState>() async {
    if (connection.state is T) return connection.state as T;
    return (await connection.states
            .firstWhere((s) => s is T)
            .timeout(const Duration(seconds: 3)))
        as T;
  }

  setUp(() {
    server = FakeXxdServer();
    http = FakeXxdHttp(serverInfoOk());
  });

  tearDown(() => connection.dispose());

  test(
    'logs in, keeps login-time pushes and picks up the session id',
    () async {
      connect();
      final pushed = <String>[];
      final sub = connection.packets.listen((p) => pushed.add(p.apiName));

      final result = await connection.start();

      expect(result.valueOrNull?.userId, 40);
      final login = server.requests.single;
      expect(login['method'], 'userlogin');
      expect(login['params'], [
        '',
        'demo',
        xxdPasswordAuthKey('secret'),
        {'status': 'online', 'simple': false},
      ]);
      await pumpEventQueue();
      expect(
        pushed,
        containsAllInOrder(['userlogin', 'chatgetlist', 'syssessionid']),
      );
      final online = connection.state as XxdOnline;
      expect(online.session.sessionId, 'session-1');
      await sub.cancel();
    },
  );

  test(
    'matches replies by rid, or by method when the reply has no rid',
    () async {
      server.onRequest = (req) => {
        'method': req['method'],
        if (req['method'] == 'chatgetmessageinfo') 'rid': req['rid'],
        'result': 'success',
        'data': {'echo': req['params']},
      };
      connect();
      await connection.start();

      final byRid = await connection.request(
        const XxdRequest('chatGetMessageInfo', params: ['g1']),
      );
      final byMethod = await connection.request(
        const XxdRequest('messageSync', params: ['g1', 5, true, 10, false]),
      );

      expect((byRid.valueOrNull!.data! as Map)['echo'], ['g1']);
      expect((byMethod.valueOrNull!.data! as Map)['echo'], [
        'g1',
        5,
        true,
        10,
        false,
      ]);
      expect(server.requests.last['userID'], 40);
      expect(server.requests.last['rid'], isNotEmpty);
    },
  );

  test('a failed reply becomes an Err with the server message', () async {
    server.onRequest = (req) => {
      'method': req['method'],
      'rid': req['rid'],
      'result': 'fail',
      'message': 'no permission',
    };
    connect();
    await connection.start();

    final result = await connection.request(const XxdRequest('chatCreate'));

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(result.failureOrNull?.message, 'no permission');
  });

  test('a silent server times the request out', () async {
    connect(timeout: const Duration(milliseconds: 50));
    await connection.start();

    final result = await connection.request(const XxdRequest('chatGetList'));

    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('rejected login stops without retrying', () async {
    server.rejectLogin = true;
    connect();

    final result = await connection.start();

    expect(result.failureOrNull, isA<AuthFailure>());
    expect(connection.state, isA<XxdStopped>());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(http.calls, 1);
  });

  test(
    'an offline start keeps retrying until the server is reachable',
    () async {
      http.queued.addAll([offline, offline]);
      connect();

      final first = await connection.start();
      expect(first.failureOrNull, isA<NetworkFailure>());
      expect(connection.state, isA<XxdReconnecting>());

      await waitForState<XxdOnline>();
      expect(http.calls, 3);
    },
  );

  test(
    'a dropped socket reconnects with a fresh handshake and login',
    () async {
      connect();
      await connection.start();

      await server.current.drop();
      await waitForState<XxdReconnecting>();
      final online = await waitForState<XxdOnline>();

      expect(online.session.userId, 40);
      expect(server.sockets, hasLength(2));
      expect(http.calls, 2);
      expect(
        server.requests.where((r) => r['method'] == 'userlogin'),
        hasLength(2),
      );
    },
  );

  test('userkickoff stops for good', () async {
    connect();
    await connection.start();

    server.current.push({'method': 'userkickoff', 'reason': 'login elsewhere'});
    final stopped = await waitForState<XxdStopped>();

    expect(stopped.kicked, isTrue);
    expect(stopped.failure, isA<AuthFailure>());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.sockets, hasLength(1));
  });

  test('pings on schedule and reconnects when the server goes quiet', () async {
    connect(ping: const Duration(milliseconds: 40));
    await connection.start();

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(server.requests.where((r) => r['method'] == 'ping'), isNotEmpty);

    // The fake never answers pings, so after 2 × interval the watchdog fires.
    await waitForState<XxdReconnecting>();
    expect(server.sockets.first.closed, isTrue);
  });

  test('stop fails pending requests and does not reconnect', () async {
    connect();
    await connection.start();

    final pending = connection.request(const XxdRequest('chatGetList'));
    await connection.stop();

    expect((await pending).failureOrNull, isA<NetworkFailure>());
    expect(connection.state, isA<XxdDisconnected>());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.sockets, hasLength(1));
  });

  test('works end to end with the real apiScheme and AES', () async {
    final scheme =
        jsonDecode(File('test/fixtures/xxd/api_scheme.json').readAsStringSync())
            as Map<String, Object?>;
    server = FakeXxdServer(scheme: scheme);
    http = FakeXxdHttp(serverInfoOk(scheme: scheme));
    server.onRequest = (req) => {
      'method': req['method'],
      'rid': req['rid'],
      'result': 'success',
      'data': {'lastMessage': 195017, 'messageCount': 1097},
    };
    connect();

    final login = await connection.start();
    final info = await connection.request(
      const XxdRequest('chatGetMessageInfo', params: ['g1']),
    );

    expect(login.valueOrNull?.userId, 40);
    expect(info.valueOrNull?.data, {
      'lastMessage': 195017,
      'messageCount': 1097,
    });
  });

  test('failures while offline are reported, not thrown', () async {
    connect();
    final result = await connection.request(const XxdRequest('chatGetList'));
    expect(result, isA<Err<XxdResponse>>());
  });
}
