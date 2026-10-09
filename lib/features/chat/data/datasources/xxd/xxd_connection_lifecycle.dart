part of 'xxd_connection.dart';

/// Session lifecycle: the `serverInfo` handshake and socket login, keep-alive
/// pings and reconnection with backoff.
mixin _XxdLifecycle on _XxdConnectionCore {
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
}
