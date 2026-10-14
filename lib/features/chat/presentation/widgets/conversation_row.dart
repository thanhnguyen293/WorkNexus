import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_typing_providers.dart';
import 'chat_labels.dart';
import 'chat_typing_label.dart';
import 'conversation_menu.dart';
import 'conversation_tile.dart';

/// One chat in the list: its tile with the right-click menu, selecting it on
/// tap. Watches who is typing in this chat itself, so a typing signal in any
/// chat redraws only the rows it concerns, not the whole list.
class ConversationRow extends ConsumerWidget {
  const ConversationRow({
    super.key,
    required this.accountId,
    required this.chat,
    required this.title,
    required this.users,
    required this.selected,
    required this.compact,
  });

  final String accountId;
  final ChatConversation chat;
  final String title;
  final Map<int, ChatUser> users;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(
      chatTypingUsersProvider((accountId: accountId, chatGid: chat.gid)),
    );
    final withPeer = _withPeer(chat);
    return GestureDetector(
      onSecondaryTapUp: (d) =>
          showConversationMenu(context, ref, chat: chat, at: d.globalPosition),
      child: ConversationTile(
        chat: chat,
        title: title,
        avatar: chatAvatarStyle(chat, users),
        presence: withPeer ? chatPresenceOf(users, chat.peerUserId) : null,
        verified: withPeer
            ? chatVerifiedBadge(context, users, chat.peerUserId)
            : null,
        lastSender: _lastSender(context, chat, users),
        typing: _typingLabel(context, chat, users, typing),
        selected: selected,
        compact: compact,
        onTap: () =>
            ref.read(selectedChatGidProvider(accountId).notifier).state =
                chat.gid,
      ),
    );
  }
}

/// A one-to-one chat with someone else: their presence and badge show.
bool _withPeer(ChatConversation chat) =>
    chat.type == ChatType.one2one && !chat.isMyCloud;

/// Who sent a group's last message, for its row; null for one-to-one
/// chats (always the other person or you) and for system notices.
String? _lastSender(
  BuildContext context,
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  final last = chat.lastMessage;
  if (chat.type == ChatType.one2one || last == null) return null;
  if (last.content is NotificationContent || last.isNotice) return null;
  return last.isMine
      ? AppL10n.of(context).chatYou
      : chatUserName(context, users, last.senderId);
}

/// Who is typing in [chat], for its row: just "typing…" in a one-to-one
/// chat (it can only be the other person), names in a group.
String? _typingLabel(
  BuildContext context,
  ChatConversation chat,
  Map<int, ChatUser> users,
  List<int> typing,
) {
  if (typing.isEmpty) return null;
  return chat.type == ChatType.one2one
      ? AppL10n.of(context).chatTyping
      : chatTypingLabel(context, users, typing);
}
