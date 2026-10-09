import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
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
    return ChatSidePanelFrame(
      title: AppL10n.of(context).chatMembersTitle,
      onBack: () => backToChatInfo(ref, thread, infoRoom: infoRoom),
      onClose: infoRoom ? null : () => closeChatSidePanel(ref, thread),
      child: ChatMemberList(
        chat: thread,
        users: users,
        ownerAccount: chat.ownerAccount,
      ),
    );
  }
}
