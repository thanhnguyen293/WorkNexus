part of 'xxd_chat_repository.dart';

/// Connection lifecycle: connect / disconnect, certificate trust and the
/// per-account status channel fed by the connection's state.
mixin _ChatConnection on _XxdChatCore {
  // ---- connection --------------------------------------------------------------

  final _statuses = <String, StatusChannel>{};

  @override
  Stream<ChatConnectionStatus> watchStatus(String accountId) =>
      _status(accountId).watch();

  @override
  Future<Result<void>> connect(String accountId) async {
    final existing = _sessions[accountId];
    if (existing != null && existing.isActive) return const Ok(null);
    await _closeSession(accountId);

    final credentials = await _resolver.resolve(accountId);
    final XxdCredentials creds;
    switch (credentials) {
      case Ok(:final value):
        creds = value;
      case Err(:final failure):
        _status(accountId)
            .set(ChatConnectionStatus.signedOut(message: failure.message));
        return Err(failure);
    }
    await _local.failStalePending(
      accountId,
      _now().subtract(XxdChatRepository.pendingTimeout),
    );

    final connection = _openConnection(creds);
    final session = ChatSession(connection);
    _sessions[accountId] = session;
    session.listen(
      onPacket: (p) => session.enqueue(() => _ingest(accountId, session, p)),
      onState: (s) => _onState(accountId, session, s),
      onError: _onError,
    );
    final result = await connection.start();
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<void> disconnect(String accountId) async {
    await _closeSession(accountId);
    _status(accountId).set(const ChatConnectionStatus.offline());
  }

  @override
  Future<Result<void>> trustCertificate(
    String accountId,
    String fingerprint,
  ) async {
    try {
      await _local.saveChatAccount(
        ChatAccountsCompanion(
          accountId: Value(accountId),
          pinnedFingerprint: Value(fingerprint),
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not save the certificate', cause: e));
    }
    await _closeSession(accountId);
    return connect(accountId);
  }

  void _onState(String accountId, ChatSession session, XxdConnectionState s) {
    if (_sessions[accountId] != session) return;
    final status = switch (s) {
      XxdDisconnected() => const ChatConnectionStatus.offline(),
      XxdConnecting() => const ChatConnectionStatus.connecting(),
      XxdOnline(:final session) => ChatConnectionStatus.online(
        selfUserId: session.userId,
      ),
      XxdReconnecting(:final delay, :final lastFailure) =>
        ChatConnectionStatus.reconnecting(
          retryIn: delay,
          reason: lastFailure.message,
        ),
      XxdStopped(failure: final UntrustedCertificateFailure f) =>
        ChatConnectionStatus.needsTrust(
          host: f.host,
          fingerprint: f.fingerprint,
          subject: f.subject,
          issuer: f.issuer,
        ),
      XxdStopped(:final failure, :final kicked) =>
        ChatConnectionStatus.signedOut(
          message: failure.message,
          kicked: kicked,
        ),
    };
    _status(accountId).set(status);
    if (s is XxdOnline) {
      session.selfUserId = s.session.userId;
      // Notifications (and xuanbot) arrive as `syncNotifications` once
      // asked for, as the official client does after signing in.
      unawaited(
        session.connection.request(
          const XxdRequest('getNotification', params: []),
        ),
      );
      session.enqueue(
        () => _local.saveChatAccount(
          ChatAccountsCompanion(
            accountId: Value(accountId),
            userId: Value(s.session.userId),
          ),
        ),
      );
    }
  }

  Future<void> _closeSession(String accountId) async {
    final session = _sessions.remove(accountId);
    await session?.close();
  }

  StatusChannel _status(String accountId) =>
      _statuses.putIfAbsent(accountId, StatusChannel.new);
}
