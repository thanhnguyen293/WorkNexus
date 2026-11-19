import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';

/// Makes a member an admin of a group, or a plain member again. As in the
/// official client, only the group's owner may, and not for themself.
class SetGroupAdmin {
  const SetGroupAdmin(this._repository);

  final ChatGroupRepository _repository;

  bool canSetAdmins(ChatConversation chat, {required String? selfAccount}) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      selfAccount != null &&
      selfAccount == chat.ownerAccount;

  Future<Result<void>> call(
    ChatConversation chat,
    int userId, {
    required bool admin,
    required int? selfUserId,
    required String? selfAccount,
  }) async {
    if (!canSetAdmins(chat, selfAccount: selfAccount) || userId == selfUserId) {
      return const Err(
        UnexpectedFailure('Only the owner can change who are admins'),
      );
    }
    return _repository.setGroupAdmins(chat.accountId, chat.gid, [
      userId,
    ], admin: admin);
  }
}
