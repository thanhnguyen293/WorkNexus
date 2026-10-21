import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../providers/chat_providers.dart';
import 'reaction_chips.dart';
import 'thread_chip.dart';

/// What hangs under a message's bubble: the reactions to it and, when it
/// roots a thread, the thread chip ([thread] null: none to show here).
class MessageUnderBubble extends StatelessWidget {
  const MessageUnderBubble({
    super.key,
    required this.chat,
    required this.message,
    required this.users,
    required this.alignEnd,
    required this.onOpenThread,
    this.thread,
  });

  final ChatThreadKey chat;
  final ChatMessage message;
  final Map<int, ChatUser> users;
  final bool alignEnd;
  final ThreadSummary? thread;
  final void Function(int messageId) onOpenThread;

  @override
  Widget build(BuildContext context) {
    final serverId = message.serverId;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ReactionChips(
          chat: chat,
          message: message,
          users: users,
          alignEnd: alignEnd,
        ),
        if (thread case final summary? when serverId != null)
          Padding(
            padding: EdgeInsets.only(top: context.spacing.sm),
            child: ThreadChip(
              summary: summary,
              users: users,
              onTap: () => onOpenThread(serverId),
            ),
          ),
      ],
    );
  }
}
