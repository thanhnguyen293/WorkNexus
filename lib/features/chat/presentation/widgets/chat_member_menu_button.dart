import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

enum _MemberAction { toggleAdmin, transferOwner, remove }

/// On a member's row, for the group's owner: a "…" menu to make them an
/// admin (or a plain member again), hand them the group, or remove them.
/// Nothing for anyone else.
class ChatMemberMenuButton extends ConsumerWidget {
  const ChatMemberMenuButton({
    super.key,
    required this.thread,
    required this.chat,
    required this.userId,
    required this.name,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final int userId;
  final String name;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ChatGroupRights rights,
  ) async {
    final l = AppL10n.of(context);
    final isAdmin = chat.adminIds.contains(userId);
    final box = context.findRenderObject() as RenderBox?;
    final actions = [
      if (rights.manageAdmins) ...[
        _MemberAction.toggleAdmin,
        _MemberAction.transferOwner,
      ],
      if (rights.removeMembers) _MemberAction.remove,
    ];
    final picked = await showAppContextMenu(
      context,
      at: box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
      entries: [
        for (final action in actions)
          switch (action) {
            _MemberAction.toggleAdmin => AppMenuEntry(
              icon: isAdmin ? LucideIcons.shieldOff300 : LucideIcons.shield300,
              label: isAdmin ? l.chatRemoveAdmin : l.chatMakeAdmin,
            ),
            _MemberAction.transferOwner => AppMenuEntry(
              icon: LucideIcons.crown300,
              label: l.chatTransferOwner,
            ),
            _MemberAction.remove => AppMenuEntry(
              icon: LucideIcons.userMinus300,
              label: l.chatRemoveMember,
              destructive: true,
              dividerBefore: true,
            ),
          },
      ],
    );
    if (picked == null || !context.mounted) return;
    await _run(context, ref, actions[picked], isAdmin: isAdmin);
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _MemberAction action, {
    required bool isAdmin,
  }) async {
    final l = AppL10n.of(context);
    if (action != _MemberAction.toggleAdmin) {
      final transfer = action == _MemberAction.transferOwner;
      final label = transfer ? l.chatTransferOwner : l.chatRemoveMember;
      final confirmed = await AppConfirmDialog.show(
        context,
        title: label,
        message: transfer
            ? l.chatTransferOwnerConfirm(name, chat.name)
            : l.chatRemoveMemberConfirm(name, chat.name),
        confirmLabel: label,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }
    final accountId = thread.accountId;
    final self = ref.read(chatSelfUserIdProvider(accountId)).value;
    final account = ref.read(chatSelfAccountProvider(accountId));
    final controller = ref.read(chatGroupControllerProvider);
    final result = await switch (action) {
      _MemberAction.toggleAdmin => controller.setAdmin(
        chat,
        userId,
        admin: !isAdmin,
        selfUserId: self,
        selfAccount: account,
      ),
      _MemberAction.transferOwner => controller.transferOwnership(
        chat,
        userId,
        selfUserId: self,
        selfAccount: account,
      ),
      _MemberAction.remove => controller.removeMember(
        chat,
        userId,
        selfUserId: self,
        selfAccount: account,
      ),
    };
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        if (action == _MemberAction.remove) {
          // Members are fetched on demand, not stored: ask again.
          ref
            ..invalidate(chatMembersProvider(thread))
            ..invalidate(chatMemberCountProvider(thread));
          showChatSnack(context, l.chatMemberRemoved);
        } else if (action == _MemberAction.transferOwner) {
          showChatSnack(context, l.chatOwnerTransferred);
        }
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rights = ref.watch(chatGroupRightsProvider(thread));
    if (!rights.manageAdmins && !rights.removeMembers) {
      return const SizedBox.shrink();
    }
    return Builder(
      // Its own context, so the menu opens under the button.
      builder: (context) => AppIconButton(
        icon: LucideIcons.ellipsis300,
        size: AppIconButtonSize.small,
        tooltip: AppL10n.of(context).chatMemberActions,
        onPressed: () => _open(context, ref, rights),
      ),
    );
  }
}
