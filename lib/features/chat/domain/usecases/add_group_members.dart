import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';
import 'can_send_to_chat.dart';

/// Adds people to a group chat. As in the official client: the owner and
/// admins may; so may anyone allowed to post, unless the group keeps
/// inviting to admins (`adminInvite`) and is not public. Never once the
/// group is dismissed. The server has the final say.
class AddGroupMembers {
  const AddGroupMembers(this._repository);

  final ChatRepository _repository;
  final _canSend = const CanSendToChat();

  bool canAdd(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) {
    if (chat.type != ChatType.group || chat.archived) return false;
    final isAdmin =
        (selfUserId != null && chat.adminIds.contains(selfUserId)) ||
        (selfAccount != null && selfAccount == chat.ownerAccount);
    if (isAdmin) return true;
    return _canSend(chat, selfUserId: selfUserId, selfAccount: selfAccount) &&
        (!chat.adminInvite || chat.isPublic);
  }

  Future<Result<void>> call(ChatConversation chat, List<int> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) {
      return const Err(UnexpectedFailure('Pick someone to add'));
    }
    return _repository.addGroupMembers(chat.accountId, chat.gid, ids);
  }
}
