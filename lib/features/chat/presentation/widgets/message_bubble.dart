import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'bubble_tail.dart';
import 'chat_avatar.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'chat_panels.dart';
import 'chat_style.dart';
import 'chat_user_profile_dialog.dart';
import 'message_actions.dart';
import 'message_body.dart';
import 'message_bubble_box.dart';
import 'message_footer.dart';
import 'message_hover_actions.dart';
import 'message_link_previews.dart';
import 'message_translation_view.dart';
import 'reply_quote.dart';
import 'thread_chip.dart';

/// Widest an image or video is shown inline.
const double _kMaxMediaWidth = 360;

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

  bool get _isMedia =>
      !message.deleted &&
      switch (message.content) {
        ImageContent() || EmojiContent() => true,
        final FileContent f => isVideoFile(f) && f.fileId > 0,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ChatStyle.watch(ref, context);
    final s = context.spacing;
    final mine = message.isMine;
    final ink = style.ink(mine: mine);
    final name = mine && !users.containsKey(message.senderId)
        ? AppL10n.of(context).chatYou
        : chatUserName(context, users, message.senderId);
    final showName = !mine && showSender && firstOfRun;
    final nameText = ChatProfileTap(
      accountId: chat.accountId,
      userId: message.senderId,
      child: Text(
        name,
        style: context.typography.captionStrong.copyWith(
          color: style.nameColor(message.senderId),
        ),
      ),
    );
    final showFooter = switch (style.time) {
      _ when message.sendState != SendState.sent => true,
      ChatTimePlacement.belowContent => lastOfRun,
      ChatTimePlacement.insideEnd => true,
      ChatTimePlacement.separators => false,
    };
    final footer = showFooter
        ? Align(
            alignment: style.time == ChatTimePlacement.insideEnd
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: MessageFooter(
              accountId: chat.accountId,
              message: message,
              tick: style.ticks && mine ? style.palette.outgoingTicks : null,
            ),
          )
        : null;
    final quote = _hasQuote
        ? ReplyQuote(
            chat: chat,
            replyToId: message.replyToId!,
            users: users,
            onTap: () => jumpToChatMessage(ref, chat, message.replyToId!),
          )
        : null;
    final body = MessageBody(accountId: chat.accountId, message: message);
    final media = _isMedia && quote == null;

    // The tail belongs to the bubble that touches the avatar side.
    final tailed =
        style.tail != null &&
        !media &&
        switch (style.tail!) {
          BubbleTailKind.curlBottom => lastOfRun,
          BubbleTailKind.triangleTop => true,
        };

    // Styles with tails keep the tail's width free on every message, tailed
    // or not, so bubbles, media and outside quotes share one edge.
    final gutter = style.tail == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: mine ? 0 : BubbleTail.width,
            right: mine ? BubbleTail.width : 0,
          );

    final Widget bubble;
    if (media) {
      bubble = Padding(
        padding: gutter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxMediaWidth),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [body, ?footer],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName && style.name == ChatNamePlacement.insideBubble)
              Padding(
                padding: EdgeInsets.only(bottom: s.xxs),
                child: nameText,
              ),
            if (style.quote == ChatQuotePlacement.inside) ?quote,
            body,
            MessageTranslationView(accountId: chat.accountId, gid: message.gid),
            // Compact previews of the links, under the text.
            MessageLinkPreviews(message: message),
            ?footer,
          ],
        ),
      );
      bubble = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: style.maxWidth),
        // A tailed box makes its own room for the tail.
        child: tailed ? box : Padding(padding: gutter, child: box),
      );
    }

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (showName && style.name == ChatNamePlacement.aboveBubble)
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
          alignEnd: mine,
          // Reply, and "open thread" for a message in one, as own buttons.
          buttons: _inThread ? 2 : 1,
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
        if (thread case final summary? when message.serverId != null)
          Padding(
            padding: EdgeInsets.only(top: s.sm),
            child: ThreadChip(
              summary: summary,
              users: users,
              onTap: () => onOpenThread(message.serverId!),
            ),
          ),
      ],
    );

    final hasSlot =
        (!mine || style.ownAvatar) && (showSender || style.avatarInDirectChats);
    final avatarVisible = switch (style.avatar) {
      ChatAvatarPlacement.firstOfRun => firstOfRun,
      ChatAvatarPlacement.lastOfRun => lastOfRun,
      ChatAvatarPlacement.everyMessage => true,
    };
    final slot = SizedBox(
      width: style.avatarSize,
      child: avatarVisible
          ? ChatProfileTap(
              accountId: chat.accountId,
              userId: message.senderId,
              child: ChatAvatar(
                name: name,
                imageUrl: chatAvatarUrl(users, message.senderId),
                verified: chatVerifiedBadge(context, users, message.senderId),
                shape: style.avatarShape,
                diameter: style.avatarSize,
              ),
            )
          : null,
    );

    return Padding(
      padding: EdgeInsets.only(top: firstOfRun ? style.groupGap : style.runGap),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: style.avatar == ChatAvatarPlacement.lastOfRun
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (hasSlot && !mine) ...[slot, SizedBox(width: s.md)],
          Flexible(child: column),
          if (hasSlot && mine) ...[SizedBox(width: s.md), slot],
        ],
      ),
    );
  }
}
