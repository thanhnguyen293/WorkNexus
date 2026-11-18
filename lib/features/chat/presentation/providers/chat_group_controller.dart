import '../../../../core/error/result.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/add_group_members.dart';
import '../../domain/usecases/dismiss_group_chat.dart';
import '../../domain/usecases/leave_group_chat.dart';
import '../../domain/usecases/remove_group_member.dart';
import '../../domain/usecases/rename_group_chat.dart';
import '../../domain/usecases/set_group_admin.dart';
import '../../domain/usecases/transfer_group_ownership.dart';
import '../../domain/usecases/update_group_settings.dart';
import '../../domain/value_objects/chat_committers.dart';

/// What a group's owner and admins can do to it — rename, dismiss, settings,
/// members, admins and ownership — and leaving it. Each delegates to one use case; widgets show the
/// returned [Result] (CLAUDE.md 2.4, 11.3).
class ChatGroupController {
  ChatGroupController(ChatRepository repository)
    : _rename = RenameGroupChat(repository),
      _dismiss = DismissGroupChat(repository),
      _add = AddGroupMembers(repository),
      _remove = RemoveGroupMember(repository),
      _leave = LeaveGroupChat(repository),
      _settings = UpdateGroupSettings(repository),
      _admin = SetGroupAdmin(repository),
      _transfer = TransferGroupOwnership(repository);

  final RenameGroupChat _rename;
  final DismissGroupChat _dismiss;
  final AddGroupMembers _add;
  final RemoveGroupMember _remove;
  final LeaveGroupChat _leave;
  final UpdateGroupSettings _settings;
  final SetGroupAdmin _admin;
  final TransferGroupOwnership _transfer;

  bool canRename(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      _rename.canRename(chat, selfUserId: selfUserId, selfAccount: selfAccount);

  bool canDismiss(ChatConversation chat, {required String? selfAccount}) =>
      _dismiss.canDismiss(chat, selfAccount: selfAccount);

  bool canAddMembers(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) => _add.canAdd(chat, selfUserId: selfUserId, selfAccount: selfAccount);

  bool canRemoveMembers(
    ChatConversation chat, {
    required String? selfAccount,
  }) => _remove.canRemove(chat, selfAccount: selfAccount);

  Future<Result<void>> rename(ChatConversation chat, String name) =>
      _rename(chat, name);

  Future<Result<void>> dismiss(
    ChatConversation chat, {
    required String? selfAccount,
  }) => _dismiss(chat, selfAccount: selfAccount);

  Future<Result<void>> addMembers(ChatConversation chat, List<int> userIds) =>
      _add(chat, userIds);

  Future<Result<void>> removeMember(
    ChatConversation chat,
    int userId, {
    required int? selfUserId,
    required String? selfAccount,
  }) => _remove(chat, userId, selfUserId: selfUserId, selfAccount: selfAccount);

  bool canLeave(ChatConversation chat, {required String? selfAccount}) =>
      _leave.canLeave(chat, selfAccount: selfAccount);

  Future<Result<void>> leave(
    ChatConversation chat, {
    required String? selfAccount,
  }) => _leave(chat, selfAccount: selfAccount);

  bool canEditSettings(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      _settings.canEdit(chat, selfUserId: selfUserId, selfAccount: selfAccount);

  /// Admins and ownership are both the owner's alone.
  bool canManageAdmins(ChatConversation chat, {required String? selfAccount}) =>
      _admin.canSetAdmins(chat, selfAccount: selfAccount) &&
      _transfer.canTransfer(chat, selfAccount: selfAccount);

  Future<Result<void>> updateSettings(
    ChatConversation chat, {
    required bool isPublic,
    required bool adminInvite,
    required ChatCommitters committers,
  }) => _settings(
    chat,
    isPublic: isPublic,
    adminInvite: adminInvite,
    committers: committers,
  );

  Future<Result<void>> setAdmin(
    ChatConversation chat,
    int userId, {
    required bool admin,
    required int? selfUserId,
    required String? selfAccount,
  }) => _admin(
    chat,
    userId,
    admin: admin,
    selfUserId: selfUserId,
    selfAccount: selfAccount,
  );

  Future<Result<void>> transferOwnership(
    ChatConversation chat,
    int userId, {
    required int? selfUserId,
    required String? selfAccount,
  }) =>
      _transfer(chat, userId, selfUserId: selfUserId, selfAccount: selfAccount);
}
