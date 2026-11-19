import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';

/// Dismisses (disbands) a group chat for everyone. As in the official
/// client, only the group's owner may; xxd keeps the group and its history
/// but marks it dismissed, so it leaves every member's chat list.
class DismissGroupChat {
  const DismissGroupChat(this._repository);

  final ChatGroupRepository _repository;

  bool canDismiss(ChatConversation chat, {required String? selfAccount}) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      selfAccount != null &&
      selfAccount == chat.ownerAccount;

  Future<Result<void>> call(
    ChatConversation chat, {
    required String? selfAccount,
  }) async {
    if (!canDismiss(chat, selfAccount: selfAccount)) {
      return const Err(
        UnexpectedFailure('Only the owner can dismiss this group'),
      );
    }
    return _repository.dismissGroupChat(chat.accountId, chat.gid);
  }
}
