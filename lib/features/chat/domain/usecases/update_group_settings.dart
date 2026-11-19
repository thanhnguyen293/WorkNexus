import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_group_repository.dart';
import '../value_objects/chat_committers.dart';

/// Changes a group's settings: whether it is public, whether only its owner
/// and admins add people, and who may post. As in the official client, the
/// owner and admins may, while it is not dismissed.
class UpdateGroupSettings {
  const UpdateGroupSettings(this._repository);

  final ChatGroupRepository _repository;

  bool canEdit(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      chat.type == ChatType.group &&
      !chat.archived &&
      ((selfUserId != null && chat.adminIds.contains(selfUserId)) ||
          (selfAccount != null && selfAccount == chat.ownerAccount));

  Future<Result<void>> call(
    ChatConversation chat, {
    required bool isPublic,
    required bool adminInvite,
    required ChatCommitters committers,
  }) async {
    if (committers.scope == ChatSendScope.selected &&
        committers.userIds.isEmpty) {
      return const Err(UnexpectedFailure('Pick who may post'));
    }
    return _repository.setGroupSettings(
      chat.accountId,
      chat.gid,
      isPublic: isPublic,
      // Anyone may join a public group, so keeping invites to admins would
      // mean nothing (the official client clears it too).
      adminInvite: !isPublic && adminInvite,
      committers: committers.encode(),
    );
  }
}
