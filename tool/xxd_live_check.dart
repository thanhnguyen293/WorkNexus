// Live check of the Dart xxd connection against a real ZenTao chat server.
//
//   fvm dart run tool/xxd_live_check.dart --server https://host:11443 \
//     --account <user> [--pin AB:CD:…] [--listen 120] [--server-name ""]
//
// Walks the trust-on-first-use flow for a self-signed certificate, logs in,
// checks that replies echo `rid`, then prints pushed messages and connection
// state changes for --listen seconds (to confirm messages from other users
// arrive and whether another login kicks this session).
//
// The password is read from stdin without echo. Nothing is written to disk.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_connection.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_connection_state.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_http_datasource.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_packet.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_server_info.dart';

Future<void> main(List<String> argv) async {
  final args = _parse(argv);
  final server = args['server'];
  final account = args['account'];
  if (server == null || account == null) {
    stderr.writeln(
      'Usage: fvm dart run tool/xxd_live_check.dart --server <https://host:11443> '
      '--account <user> [--pin <fingerprint>] [--listen <seconds>]',
    );
    exit(2);
  }
  final password = _readPassword();
  var pin = args['pin'];
  final listen = Duration(seconds: int.tryParse(args['listen'] ?? '') ?? 60);
  const http = XxdHttpDatasource(clientVersion: kXxdClientVersion);

  while (true) {
    final connection = XxdConnection(
      credentials: XxdCredentials(
        server: Uri.parse(server),
        account: account,
        password: password,
        serverName: args['server-name'] ?? '',
        pinnedFingerprint: pin,
      ),
      http: http,
    );
    final chats = <Map<String, Object?>>[];
    final sub = connection.packets.listen(
      (p) => _onPacket(p, chats),
      onError: (Object e) => _log('!! undecodable frame: $e'),
    );
    final stateSub = connection.states.listen(
      (s) => _log('state: ${_describe(s)}'),
    );

    _log(
      '[1] Connecting to $server as $account${pin == null ? '' : ' (pinned)'}',
    );
    final result = await connection.start();
    if (result case Err(:final UntrustedCertificateFailure failure)) {
      await connection.dispose();
      await sub.cancel();
      await stateSub.cancel();
      _log('    Untrusted certificate for ${failure.host}');
      _log('      subject:     ${failure.subject}');
      _log('      issuer:      ${failure.issuer}');
      _log('      fingerprint: ${failure.fingerprint}');
      stdout.write('    Trust this certificate and continue? [y/N] ');
      if ((stdin.readLineSync() ?? '').trim().toLowerCase() != 'y') exit(1);
      pin = failure.fingerprint;
      _log('    Pinned. Next time pass --pin ${failure.fingerprint}');
      continue;
    }
    if (result case Err(:final failure)) {
      _log('    Login failed: $failure');
      await connection.dispose();
      exit(1);
    }

    final session = result.valueOrNull!;
    _log(
      '    Logged in as #${session.userId} ${session.user['account']} '
      '(${session.user['realname']}), xxd ${session.serverVersion}',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final online = connection.state;
    _log(
      '    sessionID: ${online is XxdOnline && online.session.sessionId != null ? 'received' : 'MISSING'}',
    );

    _log('\n[2] Request/reply matching');
    final target = chats.isEmpty ? null : chats.first['gid'] as String?;
    if (target == null) {
      _log('    no chats to query');
    } else {
      final reply = await connection.request(
        XxdRequest('chatGetMessageInfo', params: [target], rid: 'live-check-1'),
      );
      switch (reply) {
        case Ok(:final value):
          _log(
            '    chatGetMessageInfo → ${jsonEncode(value.data)}; reply rid '
            '${value.rid == 'live-check-1' ? 'echoed ✓' : '"${value.rid}" (matched by method)'}',
          );
        case Err(:final failure):
          _log('    chatGetMessageInfo failed: $failure');
      }
    }

    _log(
      '\n[3] Listening ${listen.inSeconds}s — have a teammate message you, '
      'and/or log in to the xuanxuan app to see if this session is kicked.',
    );
    final until = DateTime.now().add(listen);
    while (DateTime.now().isBefore(until) && connection.state is! XxdStopped) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    _log('\nDone: final state ${_describe(connection.state)}');
    await sub.cancel();
    await stateSub.cancel();
    await connection.dispose();
    exit(0);
  }
}

void _onPacket(XxdResponse p, List<Map<String, Object?>> chats) {
  switch (p.apiName) {
    case 'chatgetlist':
      final data = p.data;
      if (data is List) chats.addAll(data.whereType<Map<String, Object?>>());
      _log('    <- chatgetlist: ${chats.length} chats');
    case 'messagesend':
      final data = p.data;
      final list = data is List ? data : [data];
      for (final m in list.whereType<Map<Object?, Object?>>()) {
        final content = '${m['content'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ');
        _log(
          '    <- message #${m['id']} in ${m['cgid']} from user ${m['user']} '
          '[${m['contentType']}] '
          '${content.length > 60 ? '${content.substring(0, 60)}…' : content}',
        );
      }
    case 'userlogin' || 'syssessionid' || 'ping' || 'chatgetmessageinfo':
      break;
    default:
      _log('    <- ${p.apiName} (${p.result ?? '-'})');
  }
}

String _describe(XxdConnectionState s) => switch (s) {
  XxdDisconnected() => 'disconnected',
  XxdConnecting() => 'connecting',
  XxdOnline() => 'online',
  XxdReconnecting(:final attempt, :final delay, :final lastFailure) =>
    'reconnecting #$attempt in ${delay.inSeconds}s ($lastFailure)',
  XxdStopped(:final failure, :final kicked) =>
    'stopped${kicked ? ' (KICKED)' : ''}: $failure',
};

String _readPassword() {
  stdout.write('Password: ');
  stdin.echoMode = false;
  try {
    return stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }
}

Map<String, String> _parse(List<String> argv) {
  final out = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    final next = i + 1 < argv.length ? argv[i + 1] : null;
    out[argv[i].substring(2)] = next != null && !next.startsWith('--')
        ? argv[++i]
        : '';
  }
  return out;
}

void _log(String line) => stdout.writeln(line);
