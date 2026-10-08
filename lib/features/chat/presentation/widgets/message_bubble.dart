import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
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
import 'chat_style.dart';
import 'message_actions.dart';
import 'message_body.dart';
import 'message_footer.dart';
import 'message_hover_actions.dart';
import 'reply_quote.dart';
import 'thread_chip.dart';

/// Widest an image or video is shown inline.
const double _kMaxMediaWidth = 360;

/// One message, drawn the way the user's chat style (WorkNexus, Telegram,
/// Zalo, Messenger, WeChat) draws it: bubble colours and shape, tail, avatar
/// size/shape/position, where the name, time and reply quote go.
/// Consecutive messages from one sender form a run.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.chat,
    required this.message,
    required this.users,
    required this.onOpenThread,
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

  bool get _hasQuote =>
      showQuote && message.replyToId != null && !message.deleted;

  bool get _isMedia =>
      !message.deleted &&
      switch (message.content) {
        ImageContent() => true,
        final FileContent f => isVideoFile(f) && f.fileId > 0,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ChatStyle.of(
      ref.watch(appSettingsProvider.select((s) => s.chatAppearance)),
      context,
    );
    final s = context.spacing;
    final mine = message.isMine;
    final ink = style.ink(mine: mine);
    final name = mine && !users.containsKey(message.senderId)
        ? AppL10n.of(context).chatYou
        : chatUserName(context, users, message.senderId);
    final showName = !mine && showSender && firstOfRun;
    final nameText = Text(
      name,
      style: context.typography.captionStrong.copyWith(
        color: style.nameColor(message.senderId),
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
            onTap: () => onOpenThread(message.replyToId!),
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

    final Widget bubble;
    if (media) {
      bubble = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxMediaWidth),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [body, ?footer],
        ),
      );
    } else {
      final border = style.bubbleBorder(mine: mine);
      final box = DecoratedBox(
        decoration: BoxDecoration(
          color: style.bubbleFill(mine: mine),
          border: border == null ? null : Border.all(color: border),
          borderRadius: style.corners(
            mine: mine,
            firstOfRun: firstOfRun,
            lastOfRun: lastOfRun,
            withTail: tailed,
          ),
        ),
        child: Padding(
          padding: style.padding,
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
              ?footer,
            ],
          ),
        ),
      );
      bubble = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: style.maxWidth),
        child: tailed
            ? _WithTail(
                kind: style.tail!,
                color: style.bubbleFill(mine: mine),
                mine: mine,
                child: box,
              )
            : box,
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
          Opacity(
            opacity: 0.7,
            child: Padding(
              padding: EdgeInsets.only(bottom: s.xs),
              child: quote,
            ),
          ),
        MessageHoverActions(
          alignEnd: mine,
          actions: messageActions(context, ref, message, onOpenThread),
          child: ChatBubbleTheme(ink: ink, child: bubble),
        ),
        if (style.quote == ChatQuotePlacement.below && quote != null)
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: quote,
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
          ? ChatAvatar(
              name: name,
              imageUrl: chatAvatarUrl(users, message.senderId),
              shape: style.avatarShape,
              diameter: style.avatarSize,
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

/// A bubble with its tail drawn just outside the avatar-side edge.
class _WithTail extends StatelessWidget {
  const _WithTail({
    required this.kind,
    required this.color,
    required this.mine,
    required this.child,
  });

  final BubbleTailKind kind;
  final Color color;
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tail = BubbleTail(kind: kind, color: color, pointsLeft: !mine);
    final top = kind == BubbleTailKind.triangleTop;
    return Padding(
      // Room for the tail so it is not clipped by the row.
      padding: EdgeInsets.only(
        left: mine ? 0 : BubbleTail.width,
        right: mine ? BubbleTail.width : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            left: mine ? null : -BubbleTail.width,
            right: mine ? -BubbleTail.width : null,
            top: top ? 8 : null,
            bottom: top ? null : 0,
            child: tail,
          ),
        ],
      ),
    );
  }
}
