import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';

/// Files a chat under a category of the user's own (synced by the server to
/// their other clients), or under none with an empty [category].
class SetChatCategory {
  const SetChatCategory(this._repository);

  final ChatGroupRepository _repository;

  Future<Result<void>> call(ChatConversation chat, String category) {
    final name = category.trim();
    if (name == chat.category) return Future.value(const Ok(null));
    return _repository.setChatCategory(chat.accountId, [chat.gid], name);
  }
}
