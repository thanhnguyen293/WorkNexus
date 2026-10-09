import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

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
    this.anchor,
  });

  final ChatThreadKey thread;
  final List<Object> items;
  final int index;
  final ChatStyle style;
  final Map<int, ChatUser> users;
  final Map<int, ThreadSummary> summaries;
  final bool showSenders;

  /// Set on the row a jump is scrolling to, so it can be found once built.
  final GlobalKey? anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = items[index];
    final side = EdgeInsets.symmetric(horizontal: context.spacing.xl5);
    if (item is DateTime || item is ChatTimeMarker) {
      return Padding(
        padding: side,
        child: ChatSeparator(
          style: style,
          label: item is DateTime
              ? chatDayLabel(context, item)
              : DateFormat('HH:mm').format((item as ChatTimeMarker).at),
        ),
      );
    }
    final message = item as ChatMessage;
    final older = index + 1 < items.length ? items[index + 1] : null;
    final newer = index > 0 ? items[index - 1] : null;
    final t = thread;
    final firstOfRun = !_sameRun(older, message);
    final lastOfRun = !_sameRun(newer, message);
    final bubble = MessageBubble(
      chat: t,
      message: message,
      users: users,
      firstOfRun: firstOfRun,
      lastOfRun: lastOfRun,
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
    return KeyedSubtree(
      key: anchor,
      child: _Highlight(
        thread: t,
        serverId: message.serverId,
        // The bubble's own space above it, and the next one's below it.
        gapAbove: firstOfRun ? style.groupGap : style.runGap,
        gapBelow: lastOfRun ? style.groupGap : style.runGap,
        child: Padding(padding: side, child: bubble),
      ),
    );
  }
}

/// Stronger than the selection fill: it has to catch the eye after a jump.
const double _kHighlightAlpha = 0.3;

/// Tints the full-width row of the message just jumped to, fading out again.
class _Highlight extends ConsumerWidget {
  const _Highlight({
    required this.thread,
    required this.serverId,
    required this.gapAbove,
    required this.gapBelow,
    required this.child,
  });

  final ChatThreadKey thread;
  final int? serverId;
  final double gapAbove;
  final double gapBelow;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      chatHighlightedMessageProvider(thread)
          .select((id) => id != null && id == serverId),
    );
    // The same margin above and below the message: the tint starts inside
    // the gap above it and runs as far into the next row's gap below it —
    // never onto a neighbouring bubble.
    final margin = [gapAbove, gapBelow, context.spacing.md].reduce(math.min);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: gapAbove - margin,
          bottom: -margin,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: on
                  ? context.colors.accent.withValues(alpha: _kHighlightAlpha)
                  : Colors.transparent,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
