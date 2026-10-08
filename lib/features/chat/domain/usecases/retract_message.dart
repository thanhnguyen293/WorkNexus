import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// Retracts one of your own messages within xxd's window (2 minutes, as in
/// the official client; the server enforces it too).
class RetractMessage {
  const RetractMessage(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const window = Duration(minutes: 2);

  final ChatRepository _repository;
  final DateTime Function() _now;

  /// Whether [message] may still be retracted (drives the menu item).
  bool canRetract(ChatMessage message) =>
      message.isMine &&
      !message.deleted &&
      message.serverId != null &&
      message.sendState == SendState.sent &&
      _now().difference(message.sentAt) <= window;

  Future<Result<void>> call(ChatMessage message) async {
    if (!canRetract(message)) {
      return const Err(
        UnexpectedFailure('Only your own messages from the last 2 minutes'),
      );
    }
    return _repository.retract(message.accountId, message.gid);
  }
}
