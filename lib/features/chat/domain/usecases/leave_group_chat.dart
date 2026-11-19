import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';

/// Leaves a group chat. Offered to its members but not its owner, who
/// dismisses the group instead (nobody would own it otherwise).
class LeaveGroupChat {
  const LeaveGroupChat(this._repository);

  final ChatGroupRepository _repository;

  bool canLeave(ChatConversation chat, {required String? selfAccount}) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      selfAccount != null &&
      selfAccount != chat.ownerAccount;

  Future<Result<void>> call(
    ChatConversation chat, {
    required String? selfAccount,
  }) async {
    if (!canLeave(chat, selfAccount: selfAccount)) {
      return const Err(UnexpectedFailure('The owner cannot leave the group'));
    }
    return _repository.leaveGroupChat(chat.accountId, chat.gid);
  }
}
