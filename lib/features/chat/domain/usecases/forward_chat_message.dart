import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/message_content.dart';

/// Forwards a message to one or more chats of the same account, as a new
/// message from you with the same content in each.
class ForwardChatMessage {
  const ForwardChatMessage(this._repository);

  final ChatRepository _repository;

  /// Whether [message] can be forwarded (drives the menu item): a sent,
  /// standing message with content a chat can carry — not a system notice
  /// or something this app cannot read.
  bool canForward(ChatMessage message) =>
      !message.deleted &&
      message.serverId != null &&
      message.sendState == SendState.sent &&
      switch (message.content) {
        NotificationContent() || UnsupportedContent() => false,
        _ => true,
      };

  /// Sends to each of [toChatGids] in turn; one chat failing does not stop
  /// the others. Fails with the first failure when any did.
  Future<Result<void>> call(
    ChatMessage message, {
    required List<String> toChatGids,
  }) async {
    if (!canForward(message)) {
      return const Err(UnexpectedFailure('This message cannot be forwarded'));
    }
    if (toChatGids.isEmpty) {
      return const Err(UnexpectedFailure('Pick a chat to forward to'));
    }
    Failure? first;
    for (final chatGid in toChatGids) {
      final result = await _repository.forwardMessage(
        message.accountId,
        message.gid,
        chatGid,
      );
      if (result case Err(:final failure)) first ??= failure;
    }
    return first == null ? const Ok(null) : Err(first);
  }
}
