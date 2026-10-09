import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_side_panel_frame.dart';
import 'message_bubble.dart';

/// Width of the thread panel beside the chat.
const double _kThreadPanelWidth = 380;

/// A reply thread beside the chat: the root message, every reply to it (and
/// to its replies), and a composer that replies to the root.
class ReplyThreadPanel extends ConsumerWidget {
  const ReplyThreadPanel({super.key, required this.chat, required this.rootId});

  final ChatThreadKey chat;
  final int rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final users =
        ref.watch(chatUsersProvider(chat.accountId)).asData?.value ??
        const <int, ChatUser>{};
    final root = ref
        .watch(chatMessageByIdProvider((chat: chat, serverId: rootId)))
        .asData
        ?.value;
    final allReplies =
        ref.watch(chatRepliesProvider(chat)).asData?.value ??
        const <ChatMessage>[];
    final replies = ref
        .watch(chatControllerProvider)
        .thread(rootId, allReplies)
        .replies;
    void close() {
      ref.read(openReplyThreadProvider(chat).notifier).state = null;
      ref
              .read(
                chatReplyDraftProvider((chat: chat, inThread: true)).notifier,
              )
              .state =
          null;
    }

    // The panel has no composer: a reply is written in the chat's own.
    void reply(ChatMessage message) =>
        ref
                .read(
                  chatReplyDraftProvider((chat: chat, inThread: false))
                      .notifier,
                )
                .state =
            message;

    return ChatSidePanelFrame(
      width: _kThreadPanelWidth,
      title: l.chatThread,
      closeTooltip: l.chatCloseThread,
      onClose: close,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(context.spacing.xl3),
              children: [
                if (root == null)
                  AppInlineNote(text: l.chatReplyMissing)
                else
                  MessageBubble(
                    chat: chat,
                    message: root,
                    users: users,
                    showQuote: false,
                    onOpenThread: (_) {},
                    onReply: reply,
                  ),
                if (replies.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
                    child: Text(
                      l.chatReplies(replies.length),
                      style: context.typography.captionStrong.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  // Replies to replies keep their quote so the chain is clear.
                  for (final r in replies)
                    MessageBubble(
                      key: ValueKey(r.gid),
                      chat: chat,
                      message: r,
                      users: users,
                      showQuote: r.replyToId != rootId,
                      onOpenThread: (_) {},
                      onReply: reply,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
