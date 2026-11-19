import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';

/// Renames a category by refiling every chat in it, as xxd keeps a category
/// only as a name on each chat. An empty [to] deletes the category: its
/// chats are left uncategorised.
class RenameChatCategory {
  const RenameChatCategory(this._repository);

  final ChatGroupRepository _repository;

  Future<Result<void>> call(
    String accountId,
    Iterable<ChatConversation> chats, {
    required String from,
    required String to,
  }) async {
    final name = to.trim();
    if (name == from) return const Ok(null);
    final gids = [
      for (final c in chats)
        if (c.category == from) c.gid,
    ];
    if (gids.isEmpty) {
      return const Err(UnexpectedFailure('No chat is in this category'));
    }
    return _repository.setChatCategory(accountId, gids, name);
  }
}
