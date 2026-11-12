import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/value_objects/chat_media_kind.dart';
import '../providers/chat_providers.dart';
import 'bubble_tail.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_style.dart';
import 'message_actions.dart';
import 'message_avatar_slot.dart';
import 'message_body.dart';
import 'message_bubble_box.dart';
import 'message_bubble_content.dart';
import 'message_footer.dart';
import 'message_hover_actions.dart';
import 'message_row.dart';
import 'message_sender_name.dart';
import 'message_under_bubble.dart';
import 'reaction_picker.dart';
import 'reply_quote.dart';

/// Widest an image or video is shown inline.
const double _kMaxMediaWidth = 360;

/// How much wider than the style's bubble cap a code / Markdown message may
/// grow, so code lines and tables wrap less.
const double _kWideBubbleFactor = 1.5;

/// One message, drawn the way the user's chat style draws it: bubble colours
/// and shape, tail, avatar size/shape/position, where the name, time and
/// reply quote go. Consecutive messages from one sender form a run.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.chat,
    required this.message,
    required this.users,
    required this.onOpenThread,
    required this.onReply,
    this.firstOfRun = true,
    this.lastOfRun = true,
    this.showSender = true,
    this.thread,
    this.showQuote = true,
  });

  final ChatThreadKey chat;
  final ChatMessage message;
  final Map<int, ChatUser> users;
  final bool firstOfRun;
  final bool lastOfRun;

  /// Group chats show sender names; one-to-one chats do not.
  final bool showSender;

  /// Set when this message is the root of a reply thread.
  final ThreadSummary? thread;
  final bool showQuote;
  final void Function(int messageId) onOpenThread;
  final void Function(ChatMessage message) onReply;

  bool get _inThread => message.replyToId != null || thread != null;
  bool get _hasQuote =>
      showQuote && message.replyToId != null && !message.deleted;

  bool get _isMedia => chatShowsAsMedia(message);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ChatStyle.watch(ref, context);
    final s = context.spacing;
    final mine = message.isMine;
    final ink = style.ink(mine: mine);
    final name = mine && !users.containsKey(message.senderId)
        ? AppL10n.of(context).chatYou
        : chatUserName(context, users, message.senderId);
    final headed = style.name == ChatNamePlacement.header;
    // A header names every run, own and in one-to-one chats too.
    final showName = firstOfRun && (headed || (!mine && showSender));
    final alignEnd = style.alignEnd(mine: mine);
    final overRow = showName && style.name == ChatNamePlacement.aboveRow;
    final nameText = MessageSenderName(
      accountId: chat.accountId,
      userId: message.senderId,
      name: name,
      color: style.nameColor(message.senderId),
      labelSize: style.labelSize,
      time: headed ? message.sentAt : null,
      timeColor: ink.meta,
      timeSize: style.metaSize,
    );
    final showFooter = switch (style.time) {
      _ when message.sendState != SendState.sent => true,
      ChatTimePlacement.belowContent => lastOfRun,
      ChatTimePlacement.insideEnd || ChatTimePlacement.insideAligned => true,
      ChatTimePlacement.separators || ChatTimePlacement.header => false,
    };
    final repliesInMeta = style.threadInMeta && message.serverId != null;
    final footer = showFooter
        ? MessageFooter(
            accountId: chat.accountId,
            message: message,
            tick: style.ticks && mine ? style.palette.outgoingTicks : null,
            replies: repliesInMeta ? thread?.count : null,
            onOpenReplies: () => onOpenThread(message.serverId!),
          )
        : null;
    final quote = _hasQuote
        ? ReplyQuote(
            chat: chat,
            replyToId: message.replyToId!,
            users: users,
            onTap: () => jumpToChatMessage(ref, chat, message.replyToId!),
            senderColor: style.quoteInSenderColor && !mine
                ? style.nameColor
                : null,
          )
        : null;
    final media = _isMedia && quote == null;

    final hasSlot =
        (!mine || style.ownAvatar) && (showSender || style.avatarInDirectChats);
    final avatarVisible = switch (style.avatar) {
      ChatAvatarPlacement.firstOfRun => firstOfRun,
      ChatAvatarPlacement.lastOfRun => lastOfRun,
      ChatAvatarPlacement.everyMessage => true,
    };
    // Media has no bubble to hold the name, so it goes above it in every
    // style.
    final nameAbove =
        showName &&
        !overRow &&
        (style.name != ChatNamePlacement.insideBubble || media);
    // Nothing over the bubble: a top tail points at the avatar's centre.
    final avatarLevel =
        hasSlot &&
        avatarVisible &&
        !nameAbove &&
        !(style.quote == ChatQuotePlacement.above && quote != null);

    // The tail belongs to the bubble that touches the avatar side.
    final tailed =
        style.tail != null &&
        !media &&
        switch (style.tail!) {
          BubbleTailKind.curlBottom => lastOfRun,
          // At the top: beside the avatar — on every message (WeChat) or
          // the run's first (TBChat).
          BubbleTailKind.triangleTop =>
            style.avatar == ChatAvatarPlacement.everyMessage || firstOfRun,
        };

    // Styles with tails keep the tail's width free on every message, tailed
    // or not, so bubbles, media, quotes and what's under share one edge.
    final gutter = style.tail == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: alignEnd ? 0 : BubbleTail.width,
            right: alignEnd ? BubbleTail.width : 0,
          );

    final Widget bubble;
    if (media) {
      bubble = Padding(
        padding: gutter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxMediaWidth),
          child: Column(
            crossAxisAlignment: alignEnd
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              MessageBody(accountId: chat.accountId, message: message),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.only(top: s.xs),
                  child: footer,
                ),
            ],
          ),
        ),
      );
    } else {
      final box = MessageBubbleBox(
        fill: style.bubbleFill(mine: mine),
        hoverFill: ink.hoverFill,
        borderColor: style.bubbleBorder(mine: mine),
        borderRadius: style.corners(
          mine: mine,
          firstOfRun: firstOfRun,
          lastOfRun: lastOfRun,
          withTail: tailed,
        ),
        padding: style.padding,
        mine: mine,
        tail: tailed ? style.tail : null,
        tailTip: avatarLevel ? style.avatarSize / 2 : null,
        child: MessageBubbleContent(
          accountId: chat.accountId,
          message: message,
          timeAtEnd: style.timeAtEnd(alignEnd: alignEnd),
          name: showName && style.name == ChatNamePlacement.insideBubble
              ? nameText
              : null,
          quote: style.quote == ChatQuotePlacement.inside ? quote : null,
          footer: footer,
        ),
      );
      bubble = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: chatShowsWide(message)
              ? style.maxWidth * _kWideBubbleFactor
              : style.maxWidth,
        ),
        // A tailed box makes its own room for the tail.
        child: tailed ? box : Padding(padding: gutter, child: box),
      );
    }

    final column = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (nameAbove)
          Padding(
            padding: EdgeInsets.only(left: s.xs, right: s.xs, bottom: s.xs),
            child: nameText,
          ),
        if (style.quote == ChatQuotePlacement.above && quote != null)
          ChatBubbleTheme(
            ink: style.outsideQuoteInk(),
            child: Padding(
              padding: gutter.copyWith(bottom: s.xs),
              child: quote,
            ),
          ),
        MessageHoverActions(
          alignEnd: alignEnd,
          // Reply, and "open thread" for a message in one, as own buttons.
          buttons: _inThread ? 2 : 1,
          onReact: messageCanBeReactedTo(ref, message)
              ? (at) => reactToMessage(context, ref, message, anchor: at)
              : null,
          actions: messageActions(
            context,
            ref,
            message,
            onReply,
            onOpenThread: _inThread ? onOpenThread : null,
          ),
          child: ChatBubbleTheme(ink: ink, child: bubble),
        ),
        if (style.quote == ChatQuotePlacement.below && quote != null)
          ChatBubbleTheme(
            ink: style.outsideQuoteInk(),
            child: Padding(
              padding: gutter.copyWith(top: s.xs),
              child: quote,
            ),
          ),
        Padding(
          padding: gutter,
          child: MessageUnderBubble(
            chat: chat,
            message: message,
            users: users,
            alignEnd: alignEnd,
            thread: style.threadInMeta ? null : thread,
            onOpenThread: onOpenThread,
          ),
        ),
      ],
    );

    final slot = MessageAvatarSlot(
      accountId: chat.accountId,
      senderId: message.senderId,
      name: name,
      users: users,
      style: style,
      visible: avatarVisible,
    );
    return MessageRow(
      avatar: hasSlot ? slot : null,
      alignEnd: alignEnd,
      style: style,
      top: firstOfRun ? style.groupGap : style.runGap,
      name: overRow ? nameText : null,
      child: column,
    );
  }
}
