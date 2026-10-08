import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_separator.dart';
import 'chat_style.dart';
import 'message_bubble.dart';

/// A centered time marker in the list.
final class ChatTimeMarker {
  const ChatTimeMarker(this.at);
  final DateTime at;
}

/// The rows of a reversed message list, newest first: messages, a day
/// divider after the oldest message of each day (so it sits above it on
/// screen) and, for styles without per-message times, a time marker after a
/// pause of [markerGap] (Messenger ~15 min, WeChat ~5 min).
List<Object> chatListItems(List<ChatMessage> messages, Duration? markerGap) {
  final items = <Object>[];
  for (var index = messages.length - 1; index >= 0; index--) {
    final message = messages[index];
    items.add(message);
    final previous = index > 0 ? messages[index - 1] : null;
    if (previous == null ||
        !DateUtils.isSameDay(previous.sentAt, message.sentAt)) {
      items.add(DateUtils.dateOnly(message.sentAt));
    } else if (markerGap != null &&
        message.sentAt.difference(previous.sentAt) >= markerGap) {
      items.add(ChatTimeMarker(message.sentAt));
    }
  }
  return items;
}

/// Consecutive messages from one sender within a few minutes form a run:
/// one name, one avatar, one timestamp, tighter spacing.
bool _sameRun(Object? other, ChatMessage message) =>
    other is ChatMessage &&
    other.senderId == message.senderId &&
    other.sentAt.difference(message.sentAt).abs() <= const Duration(minutes: 5);

/// Row [index] of [items]: a day divider, a time marker or a message.
class MessageListItem extends ConsumerWidget {
  const MessageListItem({
    super.key,
    required this.thread,
    required this.items,
    required this.index,
    required this.style,
    required this.users,
    required this.summaries,
    required this.showSenders,
  });

  final ChatThreadKey thread;
  final List<Object> items;
  final int index;
  final ChatStyle style;
  final Map<int, ChatUser> users;
  final Map<int, ThreadSummary> summaries;
  final bool showSenders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = items[index];
    if (item is DateTime) {
      return ChatSeparator(style: style, label: chatDayLabel(context, item));
    }
    if (item is ChatTimeMarker) {
      return ChatSeparator(
        style: style,
        label: DateFormat('HH:mm').format(item.at),
      );
    }
    final message = item as ChatMessage;
    final older = index + 1 < items.length ? items[index + 1] : null;
    final newer = index > 0 ? items[index - 1] : null;
    final t = thread;
    return MessageBubble(
      chat: t,
      message: message,
      users: users,
      firstOfRun: !_sameRun(older, message),
      lastOfRun: !_sameRun(newer, message),
      showSender: showSenders,
      thread: summaries[message.serverId],
      onOpenThread: (id) => openReplyThread(ref, t, id),
      onReply: (m) =>
          ref
                  .read(
                    chatReplyDraftProvider((chat: t, inThread: false)).notifier,
                  )
                  .state =
              m,
    );
  }
}
