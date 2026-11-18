import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

/// Renames a group chat. As in the official client, only the group's owner
/// and admins may, and not once the group is dismissed (the server checks
/// too).
class RenameGroupChat {
  const RenameGroupChat(this._repository);

  final ChatRepository _repository;

  bool canRename(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      ((selfUserId != null && chat.adminIds.contains(selfUserId)) ||
          (selfAccount != null && selfAccount == chat.ownerAccount));

  Future<Result<void>> call(ChatConversation chat, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(UnexpectedFailure('A group needs a name'));
    }
    // Nothing to send; the dialog just closes.
    if (trimmed == chat.name) return const Ok(null);
    return _repository.renameGroupChat(chat.accountId, chat.gid, trimmed);
  }
}
