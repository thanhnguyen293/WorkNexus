import '../../../../../core/error/failure.dart';

/// The logged-in xxd session.
final class XxdSession {
  const XxdSession({
    required this.user,
    required this.serverVersion,
    this.sessionId,
  });

  /// The `userlogin` reply data (`id`, `account`, `realname`, `avatar`, …).
  final Map<String, Object?> user;
  final String serverVersion;

  /// HTTP session id from `syssessionid`; signs file downloads.
  final String? sessionId;

  int get userId => (user['id'] as num).toInt();

  XxdSession withSessionId(String id) =>
      XxdSession(user: user, serverVersion: serverVersion, sessionId: id);
}

/// Lifecycle of an xxd connection.
sealed class XxdConnectionState {
  const XxdConnectionState();
}

/// Not started, or stopped by the caller.
final class XxdDisconnected extends XxdConnectionState {
  const XxdDisconnected();
}

final class XxdConnecting extends XxdConnectionState {
  const XxdConnecting();
}

final class XxdOnline extends XxdConnectionState {
  const XxdOnline(this.session);
  final XxdSession session;
}

/// The socket dropped; the next attempt runs after [delay].
final class XxdReconnecting extends XxdConnectionState {
  const XxdReconnecting({
    required this.attempt,
    required this.delay,
    required this.lastFailure,
  });

  final int attempt;
  final Duration delay;
  final Failure lastFailure;
}

/// Gave up: bad credentials, untrusted certificate, or kicked by another
/// login. Needs user action before reconnecting.
final class XxdStopped extends XxdConnectionState {
  const XxdStopped(this.failure, {this.kicked = false});

  final Failure failure;

  /// The server ended this session because the account logged in elsewhere.
  final bool kicked;
}
