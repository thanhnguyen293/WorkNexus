import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/api_scheme_codec.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_cipher.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_http_datasource.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_server_info.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_socket.dart';

const fakeToken = '0123456789abcdef0123456789abcdef';

/// `serverInfo` stand-in: returns queued results, then [fallback].
class FakeXxdHttp extends XxdHttpDatasource {
  FakeXxdHttp(this.fallback) : super(clientVersion: '9.1.2');

  final Result<XxdServerInfo> fallback;
  final Queue<Result<XxdServerInfo>> queued = Queue();
  int calls = 0;

  @override
  Future<Result<XxdServerInfo>> fetchServerInfo(XxdCredentials c) async {
    calls++;
    return queued.isNotEmpty ? queued.removeFirst() : fallback;
  }
}

Result<XxdServerInfo> serverInfoOk({Map<String, Object?>? scheme}) => Ok(
  XxdServerInfo(
    token: fakeToken,
    chatPort: 11444,
    version: 'v9.2.2',
    enableClientAes: scheme != null,
    apiScheme: scheme,
  ),
);

/// In-memory xxd: speaks plain JSON, or packed + AES when given a [scheme].
class FakeXxdServer {
  FakeXxdServer({this.scheme});

  final Map<String, Object?>? scheme;
  final List<FakeXxdSocket> sockets = [];
  final List<Map<String, Object?>> requests = [];
  bool rejectLogin = false;

  /// Pushed as `chatgetlist` right after a successful login.
  List<Map<String, Object?>> chats = [];

  /// Replies to methods other than login/ping; return null to stay silent.
  Map<String, Object?>? Function(Map<String, Object?> request)? onRequest;

  FakeXxdSocket get current => sockets.last;

  Future<XxdSocket> connect(Uri url, HttpClient client) async {
    final socket = FakeXxdSocket(this);
    sockets.add(socket);
    return socket;
  }

  void _handle(FakeXxdSocket socket, Map<String, Object?> req) {
    requests.add(req);
    switch (req['method']) {
      case 'userlogin':
        if (rejectLogin) {
          socket.push({
            'method': 'userlogin',
            'rid': req['rid'],
            'result': 'fail',
            'message': 'bad password',
          });
          return;
        }
        socket
          ..push({
            'method': 'userlogin',
            'rid': req['rid'],
            'result': 'success',
            'data': {'id': 40, 'account': 'demo', 'realname': 'Demo'},
          })
          ..push({
            'method': 'chatgetlist',
            'rid': req['rid'],
            'result': 'success',
            'data': chats,
          })
          ..push({
            'method': 'syssessionid',
            'result': 'success',
            'data': 'session-1',
          });
      case 'ping':
        break;
      default:
        final reply = onRequest?.call(req);
        if (reply != null) socket.push(reply);
    }
  }
}

class FakeXxdSocket implements XxdSocket {
  FakeXxdSocket(this.server)
    : _codec = server.scheme == null ? null : ApiSchemeCodec(server.scheme!),
      _cipher = server.scheme == null ? null : XxdCipher(fakeToken);

  final FakeXxdServer server;
  final ApiSchemeCodec? _codec;
  final XxdCipher? _cipher;
  final _frames = StreamController<Object>();
  bool closed = false;

  @override
  Stream<Object> get frames => _frames.stream;

  @override
  void send(Object frame) {
    final text = frame is String ? frame : _cipher!.decrypt(frame as List<int>);
    final json = jsonDecode(text);
    final codec = _codec;
    final req = codec != null && json is List
        ? codec.decode(json, fallback: 'requestPack')! as Map<String, Object?>
        : json as Map<String, Object?>;
    server._handle(this, req);
  }

  /// Server → client packet.
  void push(Map<String, Object?> packet) {
    if (closed) return;
    final codec = _codec;
    if (codec == null) {
      _frames.add(jsonEncode(packet));
      return;
    }
    final packed = codec.encodeToJson(
      '${packet['method']}Response',
      packet,
      fallback: 'responsePack',
    );
    _frames.add(_cipher!.encrypt(packed));
  }

  /// Simulates the server or network dropping the connection.
  Future<void> drop() async {
    closed = true;
    await _frames.close();
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!closed) await drop();
  }

  @override
  int? get closeCode => closed ? 1006 : null;

  @override
  String? get closeReason => null;
}

const offline = Err<XxdServerInfo>(NetworkFailure('offline'));
