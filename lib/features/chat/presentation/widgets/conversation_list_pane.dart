import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_account_picker.dart';
import 'chat_labels.dart';
import 'chat_list_tabs.dart';
import 'chat_search_field.dart';
import 'chat_self_avatar_button.dart';
import 'chat_side_panel_frame.dart';
import 'chat_text_scale.dart';
import 'conversation_menu.dart';
import 'conversation_tile.dart';
import 'new_chat_dialog.dart';

/// Left pane of the chat view: account picker, search and the chat list.
class ConversationListPane extends ConsumerWidget {
  const ConversationListPane({
    super.key,
    required this.accountId,
    this.compact = false,
    this.onViewProfile,
  });

  final String accountId;
  final OpenAccountProfile? onViewProfile;

  /// Collapsed to avatars (narrow window): no account picker or search,
  /// only the new-chat button above the list.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final chatsAsync = ref.watch(chatConversationsProvider(accountId));
    final users =
        ref.watch(chatUsersProvider(accountId)).asData?.value ??
        const <int, ChatUser>{};
    // The search box is hidden when collapsed: show every chat then.
    final query = compact
        ? ''
        : ref.watch(chatSearchProvider).trim().toLowerCase();
    final selected = ref.watch(selectedChatGidProvider(accountId));
    final tab = compact ? ChatListTab.all : ref.watch(chatListTabProvider);

    final visible =
        [
              for (final chat
                  in chatsAsync.asData?.value ?? const <ChatConversation>[])
                if (!chat.hidden && !chat.archived && tab.matches(chat))
                  (chat: chat, title: chatTitle(context, chat, users)),
            ]
            .where(
              (e) => query.isEmpty || e.title.toLowerCase().contains(query),
            )
            .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      child: Column(
        children: [
          // With the divider under it, as tall as the chat header beside it
          // (whose border is inside its height): the two bottom lines meet.
          if (compact)
            SizedBox(
              height: kChatHeaderHeight - context.borders.hairline,
              child: IconButton(
                tooltip: l.chatNewChat,
                onPressed: () => NewChatDialog.show(context, accountId),
                icon: Icon(
                  PhosphorIconsLight.notePencil,
                  size: context.spacing.xl4,
                  color: c.textSecondary,
                ),
              ),
            )
          else ...[
            const ChatAccountPicker(),
            Container(
              height: kChatHeaderHeight - context.borders.hairline,
              // The rows' own margin, so the avatars line up in one column.
              padding: EdgeInsets.symmetric(horizontal: context.spacing.xl3),
              alignment: Alignment.center,
              child: Row(
                children: [
                  ChatSelfAvatarButton(
                    accountId: accountId,
                    onViewProfile: onViewProfile,
                  ),
                  SizedBox(width: context.spacing.md),
                  Expanded(child: ChatSearchField(hint: l.chatSearch)),
                  SizedBox(width: context.spacing.xs),
                  _HeaderButton(
                    tooltip: l.chatNewChat,
                    icon: PhosphorIconsLight.notePencil,
                    onPressed: () => NewChatDialog.show(context, accountId),
                  ),
                ],
              ),
            ),
          ],
          const _SectionDivider(),
          if (!compact) ...[
            SizedBox(height: context.spacing.sm),
            const ChatListTabs(),
            SizedBox(height: context.spacing.sm),
            const _SectionDivider(),
          ],
          Expanded(
            child: switch (chatsAsync) {
              AsyncError() => Center(
                child: AppInlineNote(text: l.chatOffline, isError: true),
              ),
              _ when chatsAsync.isLoading && !chatsAsync.hasValue =>
                const AppInlineSpinner(),
              _ when visible.isEmpty => Center(
                child: AppInlineNote(
                  text: query.isEmpty ? l.chatNoConversations : l.chatNoMatches,
                ),
              ),
              // Rows run edge to edge: the selection fills the whole row.
              // The rows follow the chat text size, like the messages.
              _ => ChatTextScale(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    return GestureDetector(
                      key: ValueKey(e.chat.gid),
                      onSecondaryTapUp: (d) => showConversationMenu(
                        context,
                        ref,
                        chat: e.chat,
                        at: d.globalPosition,
                      ),
                      child: ConversationTile(
                        chat: e.chat,
                        title: e.title,
                        avatar: chatAvatarStyle(e.chat, users),
                        presence: e.chat.type == ChatType.one2one
                            ? chatPresenceOf(users, e.chat.peerUserId)
                            : null,
                        verified: e.chat.type == ChatType.one2one
                            ? chatVerifiedBadge(
                                context,
                                users,
                                e.chat.peerUserId,
                              )
                            : null,
                        lastSender: _lastSender(context, e.chat, users),
                        selected: e.chat.gid == selected,
                        compact: compact,
                        onTap: () =>
                            ref
                                .read(
                                  selectedChatGidProvider(accountId).notifier,
                                )
                                .state = e
                                .chat
                                .gid,
                      ),
                    );
                  },
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Who sent a group's last message, for its row; null for one-to-one
/// chats (always the other person or you) and for system notices.
String? _lastSender(
  BuildContext context,
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  final last = chat.lastMessage;
  if (chat.type == ChatType.one2one || last == null) return null;
  if (last.content is NotificationContent) return null;
  return last.isMine
      ? AppL10n.of(context).chatYou
      : chatUserName(context, users, last.senderId);
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: context.borders.hairline,
    thickness: context.borders.hairline,
    color: context.colors.border,
  );
}

/// The new-chat button beside the chat search box.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      icon,
      size: context.spacing.xl4,
      color: context.colors.textSecondary,
    ),
  );
}
