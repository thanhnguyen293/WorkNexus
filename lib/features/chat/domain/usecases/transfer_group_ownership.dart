import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

/// Hands a group over to another member, who becomes its owner. Only the
/// current owner may.
class TransferGroupOwnership {
  const TransferGroupOwnership(this._repository);

  final ChatRepository _repository;

  bool canTransfer(ChatConversation chat, {required String? selfAccount}) =>
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
    if (!canTransfer(chat, selfAccount: selfAccount) || userId == selfUserId) {
      return const Err(
        UnexpectedFailure('Only the owner can hand the group over'),
      );
    }
    return _repository.transferGroupOwnership(chat.accountId, chat.gid, userId);
  }
}
