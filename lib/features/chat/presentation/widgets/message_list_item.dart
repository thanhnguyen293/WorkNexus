import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_entrance.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';
import 'chat_notice.dart';
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
/// pause of [markerGap] (WeChat ~5 min).
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
/// one name, one avatar, one timestamp, tighter spacing. A server notice
/// stands apart, so the sender's next message still shows who sent it.
bool chatSameRun(Object? other, ChatMessage message) =>
    other is ChatMessage &&
    !other.isNotice &&
    !message.isNotice &&
    other.senderId == message.senderId &&
    other.sentAt.difference(message.sentAt).abs() <= const Duration(minutes: 5);

/// One row of the list built by [chatListItems]: a day divider, a time
/// marker or a message. Takes only what the row shows — not the whole list —
/// so an unchanged row can keep its widget (see `ListRowWidgetCache`).
class MessageListItem extends ConsumerWidget {
  const MessageListItem({
    super.key,
    required this.thread,
    required this.item,
    required this.style,
    required this.users,
    required this.showSenders,
    this.firstOfRun = true,
    this.lastOfRun = true,
    this.summary,
    this.arriving = false,
  });

  final ChatThreadKey thread;
  final Object item;
  final ChatStyle style;
  final Map<int, ChatUser> users;
  final bool showSenders;

  /// Whether the message starts / ends a run (see [chatSameRun]).
  final bool firstOfRun;
  final bool lastOfRun;

  /// Set when the message is the root of a reply thread.
  final ThreadSummary? summary;

  /// The message just arrived: its row opens and fades in (see
  /// [AppEntrance]); read only when the row is first built.
  final bool arriving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
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
    if (message.isNotice) {
      return _Highlight(
        thread: thread,
        serverId: message.serverId,
        gapAbove: style.groupGap,
        gapBelow: style.groupGap,
        child: Padding(
          padding: side,
          child: ChatNotice(style: style, message: message),
        ),
      );
    }
    final t = thread;
    final bubble = MessageBubble(
      chat: t,
      message: message,
      users: users,
      firstOfRun: firstOfRun,
      lastOfRun: lastOfRun,
      showSender: showSenders,
      thread: summary,
      onOpenThread: (id) => openReplyThread(ref, t, id),
      onReply: (m) =>
          ref
                  .read(
                    chatReplyDraftProvider((chat: t, inThread: false)).notifier,
                  )
                  .state =
              m,
    );
    return _Highlight(
      thread: t,
      serverId: message.serverId,
      // The bubble's own space above it, and the next one's below it.
      gapAbove: firstOfRun ? style.groupGap : style.runGap,
      gapBelow: lastOfRun ? style.groupGap : style.runGap,
      child: AppEntrance(
        animate: arriving,
        grow: true,
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
      chatHighlightedMessageProvider(
        thread,
      ).select((id) => id != null && id == serverId),
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
