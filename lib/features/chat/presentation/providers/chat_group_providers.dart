import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../domain/repositories/chat_group_repository.dart';
import 'chat_group_controller.dart';
import 'chat_providers.dart';

/// Group management and categories, through their domain interface.
final chatGroupRepositoryProvider = Provider<ChatGroupRepository>(
  (ref) => getIt<ChatGroupRepository>(),
);

final chatGroupControllerProvider = Provider<ChatGroupController>(
  (ref) => ChatGroupController(ref.watch(chatGroupRepositoryProvider)),
);

/// What the signed-in user may do to a group as a whole.
typedef ChatGroupRights = ({
  bool rename,
  bool dismiss,
  bool addMembers,
  bool removeMembers,
  bool leave,
  bool editSettings,
  bool manageAdmins,
});

const _none = (
  rename: false,
  dismiss: false,
  addMembers: false,
  removeMembers: false,
  leave: false,
  editSettings: false,
  manageAdmins: false,
);

/// [ChatGroupRights] for a chat: renaming, adding people and settings for
/// its owner and admins; dismissing, removing people and managing admins for
/// its owner only; leaving for everyone else. All false for anything but a
/// live group.
final chatGroupRightsProvider = Provider.autoDispose
    .family<ChatGroupRights, ChatThreadKey>((ref, key) {
      final chat = ref
          .watch(chatConversationsProvider(key.accountId))
          .value
          ?.where((c) => c.gid == key.chatGid)
          .firstOrNull;
      if (chat == null) return _none;
      final self = ref.watch(chatSelfUserIdProvider(key.accountId)).value;
      final account = ref.watch(chatSelfAccountProvider(key.accountId));
      final controller = ref.watch(chatGroupControllerProvider);
      return (
        rename: controller.canRename(
          chat,
          selfUserId: self,
          selfAccount: account,
        ),
        dismiss: controller.canDismiss(chat, selfAccount: account),
        addMembers: controller.canAddMembers(
          chat,
          selfUserId: self,
          selfAccount: account,
        ),
        removeMembers: controller.canRemoveMembers(chat, selfAccount: account),
        leave: controller.canLeave(chat, selfAccount: account),
        editSettings: controller.canEditSettings(
          chat,
          selfUserId: self,
          selfAccount: account,
        ),
        manageAdmins: controller.canManageAdmins(chat, selfAccount: account),
      );
    });

/// The signed-in user's account on [accountId]'s chat server (null until
/// both the user id and the user list are known).
final chatSelfAccountProvider = Provider.autoDispose.family<String?, String>((
  ref,
  accountId,
) {
  final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
  return ref.watch(chatUsersProvider(accountId)).value?[self]?.account;
});
