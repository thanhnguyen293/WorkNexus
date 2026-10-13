import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

/// Tells [chat]'s members whether the user is typing in it. Only person-to-
/// person chats (one-to-one and groups) carry it — not My Cloud, bots or
/// system chats.
class SendTypingStatus {
  const SendTypingStatus(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required ChatConversation chat,
    required bool typing,
  }) async {
    final supported = switch (chat.type) {
      ChatType.one2one => !chat.isMyCloud,
      ChatType.group => true,
      ChatType.bot || ChatType.system || ChatType.other => false,
    };
    if (!supported) return const Ok(null);
    return _repository.sendTyping(chat.accountId, chat.gid, typing: typing);
  }
}
