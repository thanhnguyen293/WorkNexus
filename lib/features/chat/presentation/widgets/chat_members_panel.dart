import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_group_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_add_members_dialog.dart';
import 'chat_layout.dart';
import 'chat_member_list.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';

/// Beside the chat, opened from its info: the group's members, with role
/// tabs above the list.
class ChatMembersPanel extends ConsumerWidget {
  const ChatMembersPanel({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    final l = AppL10n.of(context);
    final s = context.spacing;
    final rights = ref.watch(chatGroupRightsProvider(thread));
    return ChatSidePanelFrame(
      title: l.chatMembersTitle,
      onBack: () => backToChatInfo(ref, thread, infoRoom: infoRoom),
      onClose: () => closeChatSidePanel(ref, thread),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rights.addMembers)
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, 0),
              child: AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                icon: LucideIcons.userPlus300,
                onPressed: () => ChatAddMembersDialog.show(
                  context,
                  thread: thread,
                  chat: chat,
                  members: {
                    ...?ref
                        .read(chatMembersProvider(thread))
                        .value
                        ?.valueOrNull,
                  },
                ),
                child: Text(l.chatAddMembers),
              ),
            ),
          Expanded(
            child: ChatMemberList(
              chat: thread,
              conversation: chat,
              users: users,
              ownerAccount: chat.ownerAccount,
            ),
          ),
        ],
      ),
    );
  }
}
