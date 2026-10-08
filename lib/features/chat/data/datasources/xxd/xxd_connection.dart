import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import 'api_scheme_codec.dart';
import 'xxd_cipher.dart';
import 'xxd_connection_state.dart';
import 'xxd_frame_codec.dart';
import 'xxd_http_datasource.dart';
import 'xxd_packet.dart';
import 'xxd_server_info.dart';
import 'xxd_signing.dart';
import 'xxd_socket.dart';
import 'xxd_tls.dart';

/// 1 s, 2 s, 4 s … capped at 60 s.
Duration defaultXxdBackoff(int attempt) =>
    Duration(seconds: min(60, pow(2, max(0, attempt - 1)).toInt()));

/// One live xxd chat session: `serverInfo` handshake, socket login, request /
/// reply matching, keep-alive and reconnection.
///
/// Every incoming packet (replies included) is published on [packets]; listen
/// before [start] so packets pushed during login (`chatgetlist`, …) are seen.
class XxdConnection {
  XxdConnection({
    required this.credentials,
    required XxdHttpDatasource http,
    XxdSocketConnector connector = connectIoXxdSocket,
    this.pingInterval = const Duration(seconds: 60),
    this.requestTimeout = const Duration(seconds: 15),
    this.backoff = defaultXxdBackoff,
  }) : _http = http,
       _connector = connector;

  final XxdCredentials credentials;
  final Duration pingInterval;
  final Duration requestTimeout;
  final Duration Function(int attempt) backoff;
  final XxdHttpDatasource _http;
  final XxdSocketConnector _connector;

  final _states = StreamController<XxdConnectionState>.broadcast();
  final _packets = StreamController<XxdResponse>.broadcast();
  // Insertion-ordered (a map literal is a LinkedHashMap): replies without a
  // rid go to the oldest pending request of the same method.
  final _pending = <String, _Pending>{};
  final _uuid = const Uuid();

  XxdConnectionState _state = const XxdDisconnected();
  XxdSocket? _socket;
  StreamSubscription<Object>? _frameSub;
  XxdFrameCodec? _codec;
  XxdSession? _session;
  String? _sessionId;
  int _generation = 0;
  int _attempt = 0;
  bool _stopRequested = false;
  DateTime _lastFrameAt = DateTime.now();
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  XxdConnectionState get state => _state;
  Stream<XxdConnectionState> get states => _states.stream;

  /// Every decoded packet. Undecodable frames arrive as [ParseFailure] errors.
  Stream<XxdResponse> get packets => _packets.stream;

  /// Logs in. Network-type failures keep retrying in the background
  /// ([XxdReconnecting]); auth and certificate failures stop ([XxdStopped]).
  Future<Result<XxdSession>> start() async {
    if (_state case XxdOnline(:final session)) return Ok(session);
    _stopRequested = false;
    _attempt = 0;
    _reconnectTimer?.cancel();
    return _connect();
  }

  /// Sends [request] and waits for its reply (matched by `rid`).
  Future<Result<XxdResponse>> request(XxdRequest request) async {
    final session = _session;
    if (_state is! XxdOnline || session == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    final rid = request.rid ?? _uuid.v4();
    final reply = _expect(rid, request.apiName);
    final sent = _send(
      XxdRequest(
        request.method,
        params: request.params,
        rid: rid,
        userId: request.userId ?? session.userId,
        module: request.module,
      ),
    );
    if (sent case Err(:final failure)) {
      _pending.remove(rid);
      return Err(failure);
    }
    final result = await reply;
    return switch (result) {
      Ok(:final value) when !value.isSuccess => Err(
        UnexpectedFailure(value.message ?? '${value.apiName} failed'),
      ),
      _ => result,
    };
  }

  /// Ends the session without reconnecting.
  Future<void> stop() async {
    _stopRequested = true;
    _reconnectTimer?.cancel();
    await _teardown(const NetworkFailure('Chat connection closed'));
    _setState(const XxdDisconnected());
  }

  Future<void> dispose() async {
    await stop();
    await _states.close();
    await _packets.close();
  }

  // ---- connect ---------------------------------------------------------------

  Future<Result<XxdSession>> _connect() async {
    final generation = ++_generation;
    _setState(const XxdConnecting());
    final result = await _login(generation);
    if (generation != _generation || _stopRequested) {
      return result;
    }
    switch (result) {
      case Ok(:final value):
        _attempt = 0;
        _session = value;
        _setState(XxdOnline(value));
        _startKeepAlive(generation);
      case Err(:final failure):
        await _teardown(failure);
        _retryOrStop(failure);
    }
    return result;
  }

  Future<Result<XxdSession>> _login(int generation) async {
    final infoResult = await _http.fetchServerInfo(credentials);
    final XxdServerInfo info;
    switch (infoResult) {
      case Ok(:final value):
        info = value;
      case Err(:final failure):
        return Err(failure);
    }
    try {
      final scheme = info.apiScheme;
      _codec = XxdFrameCodec(
        clientVersion: _http.clientVersion,
        lang: _http.lang,
        device: _http.device,
        serverName: credentials.serverName,
        scheme: scheme == null ? null : ApiSchemeCodec(scheme),
        cipher: info.enableClientAes ? XxdCipher(info.token) : null,
      );
    } on ArgumentError catch (e) {
      return Err(ParseFailure('Unusable chat session token', cause: e));
    }

    final socketResult = await _open(info.socketUri(credentials.server));
    switch (socketResult) {
      case Ok(:final value):
        _attach(value, generation);
      case Err(:final failure):
        return Err(failure);
    }

    final rid = 'login_${_http.device}_${credentials.account}';
    final reply = _expect(rid, 'userlogin');
    final sent = _send(
      XxdRequest(
        'userLogin',
        rid: rid,
        params: [
          credentials.serverName,
          credentials.account,
          xxdPasswordAuthKey(credentials.password),
          {'status': 'online', 'simple': false},
        ],
      ),
    );
    if (sent case Err(:final failure)) return Err(failure);
    final login = await reply;
    switch (login) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when !value.isSuccess || value.data is! Map:
        return Err(AuthFailure(value.message ?? 'Chat login rejected'));
      case Ok(:final value):
        final session = XxdSession(
          user: Map<String, Object?>.from(value.data! as Map),
          serverVersion: info.version,
          sessionId: _sessionId,
          token: info.token,
          uploadFileSize: info.uploadFileSize,
        );
        return Ok(session);
    }
  }

  Future<Result<XxdSocket>> _open(Uri url) async {
    XxdCertificate? rejected;
    final client = createPinnedHttpClient(
      pinnedFingerprint: credentials.pinnedFingerprint,
      onRejected: (cert) => rejected = cert,
    );
    try {
      return Ok(await _connector(url, client));
    } on HandshakeException catch (e) {
      final cert = rejected;
      if (cert != null) return Err(untrustedCertificate(cert, e));
      return Err(
        NetworkFailure('TLS handshake with chat socket failed', cause: e),
      );
    } on Exception catch (e) {
      return Err(NetworkFailure('Cannot open the chat socket', cause: e));
    }
  }

  void _attach(XxdSocket socket, int generation) {
    _socket = socket;
    _lastFrameAt = DateTime.now();
    _frameSub = socket.frames.listen(
      (frame) {
        if (generation == _generation) _onFrame(frame);
      },
      onError: (Object e) {
        if (generation == _generation) {
          _onDropped(NetworkFailure('Chat socket error', cause: e));
        }
      },
      onDone: () {
        if (generation == _generation) {
          _onDropped(
            NetworkFailure(
              'Chat socket closed (${socket.closeCode ?? '-'} '
              '${socket.closeReason ?? ''})',
            ),
          );
        }
      },
    );
  }

  // ---- traffic ---------------------------------------------------------------

  Result<void> _send(XxdRequest request) {
    final socket = _socket;
    final codec = _codec;
    if (socket == null || codec == null) {
      return const Err(NetworkFailure('Chat socket is not open'));
    }
    try {
      socket.send(codec.encode(request));
      return const Ok(null);
    } on XxdProtocolException catch (e) {
      return Err(ParseFailure(e.message, cause: e.cause));
    } on Exception catch (e) {
      return Err(NetworkFailure('Cannot send on the chat socket', cause: e));
    }
  }

  Future<Result<XxdResponse>> _expect(String rid, String apiName) {
    final completer = Completer<Result<XxdResponse>>();
    _pending[rid] = _Pending(apiName, completer);
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(rid);
        return Err(NetworkFailure('No reply to $apiName from chat server'));
      },
    );
  }

  void _onFrame(Object frame) {
    if (_packets.isClosed) return;
    _lastFrameAt = DateTime.now();
    final List<XxdResponse> packets;
    try {
      packets = _codec!.decode(frame);
    } on XxdProtocolException catch (e) {
      _packets.addError(ParseFailure(e.message, cause: e.cause));
      return;
    }
    for (final packet in packets) {
      _route(packet);
      _packets.add(packet);
    }
  }

  void _route(XxdResponse packet) {
    switch (packet.apiName) {
      case 'syssessionid':
        final data = packet.data;
        final id = data is String && data.isNotEmpty
            ? data
            : packet.raw['sessionID'] as String?;
        if (id != null) {
          _sessionId = id;
          final session = _session?.withSessionId(id);
          if (session != null && _state is XxdOnline) {
            _session = session;
            _setState(XxdOnline(session));
          }
        }
      case 'userkickoff':
        unawaited(_kicked(packet));
        return;
    }
    final rid = packet.rid;
    final pending = rid != null && rid.isNotEmpty
        ? _pending.remove(rid)
        : _takeFirstPending(packet.apiName);
    pending?.completer.complete(Ok(packet));
  }

  _Pending? _takeFirstPending(String apiName) {
    for (final entry in _pending.entries) {
      if (entry.value.apiName == apiName) {
        return _pending.remove(entry.key);
      }
    }
    return null;
  }

  Future<void> _kicked(XxdResponse packet) async {
    _stopRequested = true;
    _reconnectTimer?.cancel();
    final reason = packet.raw['reason'] ?? packet.message;
    final failure = AuthFailure(
      'Signed out: the account logged in elsewhere'
      '${reason == null ? '' : ' ($reason)'}',
    );
    await _teardown(failure);
    _setState(XxdStopped(failure, kicked: true));
  }

  // ---- keep-alive & reconnect -------------------------------------------------

  void _startKeepAlive(int generation) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (generation != _generation) return;
      if (DateTime.now().difference(_lastFrameAt) > pingInterval * 2) {
        _onDropped(const NetworkFailure('Chat server stopped responding'));
        return;
      }
      _send(XxdRequest('ping', userId: _session?.userId));
    });
  }

  void _onDropped(Failure failure) {
    if (_stopRequested) return;
    final generation = ++_generation; // ignore late events from this socket
    unawaited(
      _teardown(failure).then((_) {
        if (generation == _generation && !_stopRequested) {
          _retryOrStop(failure);
        }
      }),
    );
  }

  void _retryOrStop(Failure failure) {
    if (_stopRequested) return;
    if (failure is AuthFailure || failure is UntrustedCertificateFailure) {
      _setState(XxdStopped(failure));
      return;
    }
    final attempt = ++_attempt;
    final delay = backoff(attempt);
    _setState(
      XxdReconnecting(attempt: attempt, delay: delay, lastFailure: failure),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_stopRequested) unawaited(_connect());
    });
  }

  Future<void> _teardown(Failure failure) async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _session = null;
    _sessionId = null;
    for (final p in _pending.values) {
      if (!p.completer.isCompleted) p.completer.complete(Err(failure));
    }
    _pending.clear();
    // Detach before closing so our own close is not mistaken for a drop.
    await _frameSub?.cancel();
    _frameSub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(1000, 'bye');
      } on Exception {
        // Already closed or broken; nothing left to release.
      }
    }
  }

  void _setState(XxdConnectionState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}

final class _Pending {
  _Pending(this.apiName, this.completer);
  final String apiName;
  final Completer<Result<XxdResponse>> completer;
}
