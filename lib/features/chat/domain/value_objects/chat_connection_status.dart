import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_connection_status.freezed.dart';

/// Connection state of one account's chat, as the UI needs it.
@freezed
sealed class ChatConnectionStatus with _$ChatConnectionStatus {
  const factory ChatConnectionStatus.offline() = ChatOffline;

  const factory ChatConnectionStatus.connecting() = ChatConnecting;

  const factory ChatConnectionStatus.online({required int selfUserId}) =
      ChatOnline;

  /// Lost the connection; retrying automatically after [retryIn].
  const factory ChatConnectionStatus.reconnecting({
    required Duration retryIn,
    required String reason,
  }) = ChatReconnecting;

  /// The server's certificate is self-signed or unknown; the user must
  /// confirm [fingerprint] before connecting (trust on first use).
  const factory ChatConnectionStatus.needsTrust({
    required String host,
    required String fingerprint,
    required String subject,
    required String issuer,
  }) = ChatNeedsTrust;

  /// Stopped and not retrying: bad credentials, missing password, or [kicked]
  /// because the account signed in elsewhere.
  const factory ChatConnectionStatus.signedOut({
    required String message,
    @Default(false) bool kicked,
  }) = ChatSignedOut;
}
