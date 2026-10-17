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
import '../providers/chat_search_providers.dart';
import 'chat_history_download_prompt.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_scope_filter_chip.dart';
import 'chat_search_period_button.dart';
import 'chat_search_result_list.dart';
import 'chat_search_result_tile.dart';
import 'chat_search_status.dart';
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

  void _loadMore() {
    final limit = _scope == _SearchScope.all
        ? chatGlobalSearchLimitProvider(widget.thread.accountId)
        : chatThreadSearchLimitProvider(widget.thread);
    ref.read(limit.notifier).state += chatSearchPageSize;
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
    // While the next page loads, the results so far stay listed.
    final results = matchesAsync.value ?? (messages: const [], hasMore: false);
    final matches = results.messages;

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
                      ChatSearchPeriodButton(accountId: accountId),
                    ],
                  ),
                  if (query.trim().isNotEmpty && matches.isNotEmpty) ...[
                    SizedBox(height: context.spacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        results.hasMore
                            ? l.chatSearchResultCountMore(matches.length)
                            : l.chatSearchResultCount(matches.length),
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
              child: matchesAsync.hasError
                  ? ChatSearchNote(l.chatSearchFailed, color: c.error)
                  : matchesAsync.isLoading && !matchesAsync.hasValue
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  : query.trim().isEmpty
                  ? ChatSearchNote(l.chatSearchMessages)
                  : matches.isEmpty
                  ? ChatSearchNote(l.chatSearchNoMatches)
                  : ChatSearchResultList(
                      messages: matches,
                      hasMore: results.hasMore,
                      onLoadMore: _loadMore,
                      itemBuilder: (context, msg) {
                        final chat = chatsMap[msg.chatGid];
                        return ChatSearchResultTile(
                          chatName: chat != null
                              ? chatTitle(context, chat, users)
                              : msg.chatGid,
                          sender: chatUserName(context, users, msg.senderId),
                          time: chatListTime(context, msg.sentAt),
                          preview: chatPreview(context, msg),
                          query: query,
                          isActive: msg.gid == _selectedGid,
                          onTap: () => _selectMessage(msg),
                        );
                      },
                    ),
            ),
            ChatHistoryDownloadPrompt(
              thread: widget.thread,
              offer:
                  query.trim().isNotEmpty &&
                  matchesAsync is AsyncData &&
                  !results.hasMore,
            ),
          ],
        ),
      ),
    );
  }
}
