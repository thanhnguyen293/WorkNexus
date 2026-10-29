import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/open_account_profile.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/value_objects/chat_list_tab.dart';
import '../providers/chat_providers.dart';
import 'chat_account_picker.dart';
import 'chat_labels.dart';
import 'chat_list_tabs.dart';
import 'chat_panels.dart';
import 'chat_search_field.dart';
import 'chat_self_avatar_button.dart';
import 'chat_text_scale.dart';
import 'conversation_row.dart';
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
              // `value`: a failed refresh keeps the chats already listed.
              for (final chat in chatsAsync.value ?? const <ChatConversation>[])
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
          // Sized by its controls: under the tool pane's tabs, its bottom
          // line could never meet the chat header's beside it anyway.
          if (compact)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
              child: Center(
                child: AppIconButton(
                  icon: LucideIcons.squarePen300,
                  tooltip: l.chatNewChat,
                  onPressed: () => NewChatDialog.show(context, accountId),
                ),
              ),
            )
          else ...[
            const ChatAccountPicker(),
            Padding(
              // The rows' own margin, so the avatars line up in one column.
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xl3,
                vertical: context.spacing.lg,
              ),
              child: Row(
                children: [
                  ChatSelfAvatarButton(
                    accountId: accountId,
                    onViewProfile: onViewProfile,
                  ),
                  SizedBox(width: context.spacing.md),
                  Expanded(child: ChatSearchField(hint: l.chatSearch)),
                  SizedBox(width: context.spacing.xs),
                  _MyCloudButton(accountId: accountId),
                  AppIconButton(
                    icon: LucideIcons.squarePen300,
                    tooltip: l.chatNewChat,
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
          // The list stays when a refresh fails; the failure shows above it.
          if (chatsAsync.hasError && chatsAsync.hasValue && !compact)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.xl3,
                vertical: context.spacing.sm,
              ),
              child: AppInlineNote(
                text: l.chatConnectionOffline,
                isError: true,
              ),
            ),
          Expanded(
            child: switch (chatsAsync) {
              // Collapsed to avatars: too narrow for a message, so only Retry.
              _ when chatsAsync.hasError && !chatsAsync.hasValue && compact =>
                Align(
                  alignment: Alignment.topCenter,
                  child: AppIconButton(
                    icon: LucideIcons.refreshCw300,
                    tooltip: l.retry,
                    color: c.error,
                    onPressed: () =>
                        ref.invalidate(chatConversationsProvider(accountId)),
                  ),
                ),
              _ when chatsAsync.hasError && !chatsAsync.hasValue =>
                AppStateView.error(
                  compact: true,
                  message: l.chatConnectionOffline,
                  onRetry: () =>
                      ref.invalidate(chatConversationsProvider(accountId)),
                ),
              _ when !chatsAsync.hasValue => const AppStateView.loading(
                compact: true,
              ),
              _ when visible.isEmpty && compact => const SizedBox.shrink(),
              _ when visible.isEmpty => AppStateView.empty(
                compact: true,
                icon: query.isEmpty
                    ? LucideIcons.messagesSquare300
                    : LucideIcons.searchX300,
                title: query.isEmpty ? l.chatNoConversations : l.chatNoMatches,
              ),
              // Rows run edge to edge: the selection fills the whole row.
              // The rows follow the chat text size, like the messages.
              _ => ChatTextScale(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final e = visible[i];
                    return ConversationRow(
                      key: ValueKey(e.chat.gid),
                      accountId: accountId,
                      chat: e.chat,
                      title: e.title,
                      users: users,
                      selected: e.chat.gid == selected,
                      compact: compact,
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

/// Opens My Cloud, the chat with yourself (created on first use).
class _MyCloudButton extends ConsumerWidget {
  const _MyCloudButton({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    return AppIconButton(
      icon: LucideIcons.cloud300,
      tooltip: AppL10n.of(context).chatMyCloud,
      onPressed: self == null
          ? null
          : () => openDirectChatWith(
              context,
              ref,
              accountId: accountId,
              userId: self,
            ),
    );
  }
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
