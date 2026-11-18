import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

/// Removes someone from a group chat. As in the official client, only the
/// group's owner may, and never themself.
class RemoveGroupMember {
  const RemoveGroupMember(this._repository);

  final ChatRepository _repository;

  /// Whether the signed-in user may remove members at all.
  bool canRemove(ChatConversation chat, {required String? selfAccount}) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      selfAccount != null &&
      selfAccount == chat.ownerAccount;

  Future<Result<void>> call(
    ChatConversation chat,
    int userId, {
    required int? selfUserId,
    required String? selfAccount,
  }) async {
    if (!canRemove(chat, selfAccount: selfAccount) || userId == selfUserId) {
      return const Err(
        UnexpectedFailure('Only the owner can remove other members'),
      );
    }
    return _repository.removeGroupMembers(chat.accountId, chat.gid, [userId]);
  }
}
