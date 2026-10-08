import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_panels.dart';
import 'chat_side_panel_frame.dart';
import 'message_bubble.dart';

/// Beside the chat: every pinned message, most recently pinned first.
/// Pinned messages older than what is loaded are fetched from the server.
class PinnedMessagesPanel extends ConsumerStatefulWidget {
  const PinnedMessagesPanel({
    super.key,
    required this.thread,
    required this.chat,
    required this.users,
  });

  final ChatThreadKey thread;
  final ChatConversation chat;
  final Map<int, ChatUser> users;

  @override
  ConsumerState<PinnedMessagesPanel> createState() =>
      _PinnedMessagesPanelState();
}

class _PinnedMessagesPanelState extends ConsumerState<PinnedMessagesPanel> {
  final _requested = <int>{};

  void _fetchMissing(List<int> ids) {
    final missing = ids.where(_requested.add).toList();
    if (missing.isEmpty) return;
    final t = widget.thread;
    ref
        .read(chatControllerProvider)
        .fetchMessages(t.accountId, t.chatGid, missing);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final t = widget.thread;
    final ids = widget.chat.pinnedMessageIds.reversed.toList();
    final messages = <ChatMessage>[];
    final missing = <int>[];
    for (final id in ids) {
      final found = ref
          .watch(chatMessageByIdProvider((chat: t, serverId: id)))
          .value;
      found == null ? missing.add(id) : messages.add(found);
    }
    if (missing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchMissing(missing);
      });
    }
    return ChatSidePanelFrame(
      title: l.chatPinnedMessages,
      onClose: () => closeChatSidePanel(ref, t),
      child: ids.isEmpty
          ? Padding(
              padding: EdgeInsets.all(context.spacing.xl3),
              child: AppInlineNote(text: l.chatNoPinned),
            )
          : ListView(
              padding: EdgeInsets.all(context.spacing.xl3),
              children: [
                for (final m in messages)
                  MessageBubble(
                    key: ValueKey(m.gid),
                    chat: t,
                    message: m,
                    users: widget.users,
                    onOpenThread: (id) => openReplyThread(ref, t, id),
                    onReply: (m) =>
                        ref
                                .read(
                                  chatReplyDraftProvider((
                                    chat: t,
                                    inThread: false,
                                  )).notifier,
                                )
                                .state =
                            m,
                  ),
                if (missing.isNotEmpty) const AppInlineSpinner(),
              ],
            ),
    );
  }
}
