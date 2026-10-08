import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_account_picker.dart';
import 'chat_labels.dart';
import 'chat_storage_dialog.dart';
import 'conversation_menu.dart';
import 'conversation_tile.dart';
import 'new_chat_dialog.dart';

/// Left pane of the chat view: account picker, search and the chat list.
class ConversationListPane extends ConsumerWidget {
  const ConversationListPane({
    super.key,
    required this.accountId,
    this.compact = false,
  });

  final String accountId;

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

    final visible =
        [
              for (final chat
                  in chatsAsync.asData?.value ?? const <ChatConversation>[])
                if (!chat.hidden && !chat.archived)
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
          if (compact)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
              child: IconButton(
                tooltip: l.chatNewChat,
                onPressed: () => NewChatDialog.show(context, accountId),
                icon: Icon(
                  Icons.edit_square,
                  size: context.spacing.xl4,
                  color: c.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Column(
                children: [
                  const ChatAccountPicker(),
                  Row(
                    children: [
                      Expanded(child: _SearchField(hint: l.chatSearch)),
                      IconButton(
                        tooltip: l.chatNewChat,
                        onPressed: () => NewChatDialog.show(context, accountId),
                        icon: Icon(
                          Icons.edit_square,
                          size: context.spacing.xl4,
                          color: c.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: l.chatStorage,
                        onPressed: () => ChatStorageDialog.show(context),
                        icon: Icon(
                          Icons.storage_rounded,
                          size: context.spacing.xl4,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
              _ => ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? context.spacing.sm : context.spacing.md,
                ),
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
                      selected: e.chat.gid == selected,
                      compact: compact,
                      onTap: () =>
                          ref
                              .read(selectedChatGidProvider(accountId).notifier)
                              .state = e
                              .chat
                              .gid,
                    ),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    );
    return TextField(
      onChanged: (v) => ref.read(chatSearchProvider.notifier).state = v,
      style: context.typography.secondary.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.background,
        hintText: hint,
        hintStyle: context.typography.secondary.copyWith(color: c.textTertiary),
        prefixIcon: Icon(Icons.search, size: 15, color: c.textTertiary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: context.spacing.sm,
          horizontal: context.spacing.xs,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: c.accent)),
      ),
    );
  }
}
