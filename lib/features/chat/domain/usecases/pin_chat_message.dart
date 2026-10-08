import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// Pins or unpins a message. As in the official client, anyone may pin in
/// a one-to-one chat; in groups only the owner and admins.
class PinChatMessage {
  const PinChatMessage(this._repository);

  final ChatRepository _repository;

  bool canPin(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      chat.type == ChatType.one2one ||
      (selfUserId != null && chat.adminIds.contains(selfUserId)) ||
      (selfAccount != null && selfAccount == chat.ownerAccount);

  Future<Result<void>> call(ChatMessage message, {required bool pinned}) {
    final serverId = message.serverId;
    if (serverId == null || message.deleted) {
      return Future.value(
        const Err(UnexpectedFailure('Only delivered messages can be pinned')),
      );
    }
    return _repository.setMessagePinned(
      message.accountId,
      message.chatGid,
      serverId,
      pinned: pinned,
    );
  }
}
