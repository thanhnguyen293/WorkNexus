import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_scope_filter_chip.dart';
import 'chat_search_result_tile.dart';
import 'chat_side_panel_frame.dart';

enum _SearchScope { thread, all }

/// Side panel showing chat search results across the current thread or all conversations.
class ChatGlobalSearchPanel extends ConsumerStatefulWidget {
  const ChatGlobalSearchPanel({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  ConsumerState<ChatGlobalSearchPanel> createState() =>
      _ChatGlobalSearchPanelState();
}

class _ChatGlobalSearchPanelState extends ConsumerState<ChatGlobalSearchPanel> {
  late final TextEditingController _controller;
  _SearchScope _scope = _SearchScope.all;
  String? _selectedGid;

  @override
  void initState() {
    super.initState();
    final query = ref.read(
      chatGlobalSearchQueryProvider(widget.thread.accountId),
    );
    final threadQuery = ref.read(chatThreadSearchQueryProvider(widget.thread));
    final initial = query.isNotEmpty
        ? query
        : (threadQuery.isNotEmpty ? threadQuery : '');
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref
            .read(
              chatGlobalSearchQueryProvider(widget.thread.accountId).notifier,
            )
            .state =
        query;
    ref.read(chatThreadSearchQueryProvider(widget.thread).notifier).state =
        query;
    // The in-thread bar steps through these matches: a new query starts over.
    ref
            .read(chatThreadSearchActiveIndexProvider(widget.thread).notifier)
            .state =
        -1;
  }

  void _selectMessage(ChatMessage message) {
    setState(() => _selectedGid = message.gid);
    final targetThread = (
      accountId: widget.thread.accountId,
      chatGid: message.chatGid,
    );
    if (message.chatGid != widget.thread.chatGid) {
      ref.read(chatSidePanelProvider(targetThread).notifier).state =
          ChatSidePanel.search;
      ref
              .read(selectedChatGidProvider(widget.thread.accountId).notifier)
              .state =
          message.chatGid;
    }
    if (message.serverId != null) {
      jumpToChatMessage(ref, targetThread, message.serverId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final accountId = widget.thread.accountId;

    final chats =
        ref.watch(chatConversationsProvider(accountId)).asData?.value ??
        const <ChatConversation>[];
    final chatsMap = {for (final ch in chats) ch.gid: ch};
    final users =
        ref.watch(chatUsersProvider(accountId)).asData?.value ??
        const <int, ChatUser>{};

    final query = ref.watch(chatGlobalSearchQueryProvider(accountId));
    final globalMatches = ref.watch(chatGlobalSearchResultsProvider(accountId));
    final threadMatches = ref.watch(
      chatThreadSearchMatchesProvider(widget.thread),
    );

    final matchesAsync = _scope == _SearchScope.all
        ? globalMatches
        : threadMatches;
    final matches = matchesAsync.asData?.value ?? const <ChatMessage>[];

    return ChatSidePanelFrame(
      title: l.chatSearchHistory,
      onClose: () => closeChatSidePanel(ref, widget.thread),
      child: ColoredBox(
        color: c.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(context.spacing.sm),
              child: Column(
                children: [
                  Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(context.radii.sm),
                      border: Border.all(
                        color: c.border,
                        width: context.borders.hairline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.search300,
                          size: 14,
                          color: c.textSecondary,
                        ),
                        SizedBox(width: context.spacing.xs),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: context.typography.body.copyWith(
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                            decoration: InputDecoration.collapsed(
                              hintText: l.chatSearchMessages,
                              hintStyle: context.typography.body.copyWith(
                                fontSize: 13,
                                color: c.textTertiary,
                              ),
                            ),
                            onChanged: _onQueryChanged,
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          AppIconButton(
                            icon: LucideIcons.x300,
                            size: AppIconButtonSize.small,
                            tooltip: l.clearSearch,
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Wrap(
                    spacing: context.spacing.xs,
                    runSpacing: context.spacing.xs,
                    children: [
                      ChatScopeFilterChip(
                        label: l.chatSearchAllChats,
                        selected: _scope == _SearchScope.all,
                        onTap: () => setState(() => _scope = _SearchScope.all),
                      ),
                      ChatScopeFilterChip(
                        label: l.chatSearchInThisChat,
                        selected: _scope == _SearchScope.thread,
                        onTap: () =>
                            setState(() => _scope = _SearchScope.thread),
                      ),
                    ],
                  ),
                  if (query.trim().isNotEmpty && matches.isNotEmpty) ...[
                    SizedBox(height: context.spacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${matches.length} ${matches.length == 1 ? "match" : "matches"} found',
                        style: context.typography.secondary.copyWith(
                          fontSize: 11,
                          color: c.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: context.borders.hairline,
              color: c.border,
            ),
            Expanded(
              child: matchesAsync.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  : query.trim().isEmpty
                  ? Center(
                      child: Text(
                        l.chatSearchMessages,
                        style: context.typography.secondary.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    )
                  : matches.isEmpty
                  ? Center(
                      child: Text(
                        l.chatSearchNoMatches,
                        style: context.typography.secondary.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                        vertical: context.spacing.xs,
                      ),
                      itemCount: matches.length,
                      separatorBuilder: (context, _) => Divider(
                        height: 1,
                        thickness: context.borders.hairline,
                        color: c.border,
                      ),
                      itemBuilder: (context, index) {
                        final msg = matches[index];
                        final chat = chatsMap[msg.chatGid];
                        final chatName = chat != null
                            ? chatTitle(context, chat, users)
                            : msg.chatGid;
                        final sender = chatUserName(
                          context,
                          users,
                          msg.senderId,
                        );
                        final time = chatListTime(context, msg.sentAt);
                        final preview = chatPreview(context, msg);

                        return ChatSearchResultTile(
                          chatName: chatName,
                          sender: sender,
                          time: time,
                          preview: preview,
                          query: query,
                          isActive: msg.gid == _selectedGid,
                          onTap: () => _selectMessage(msg),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
