import 'package:flutter/material.dart';

import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/chat_style_palette.dart';
import 'bubble_tail.dart';
import 'chat_avatar.dart';
import 'chat_bubble_theme.dart';

/// Where a sender's avatar sits within a run of their messages.
enum ChatAvatarPlacement { firstOfRun, lastOfRun, everyMessage }

/// Where the name of a group-chat sender goes.
enum ChatNamePlacement { aboveBubble, insideBubble }

/// Where a message's time goes.
enum ChatTimePlacement {
  /// Under the content, on the last message of a run.
  belowContent,

  /// Bottom-right inside the bubble, on every message (Telegram).
  insideEnd,

  /// Not on messages: centered time separators after pauses instead.
  separators,
}

/// Where a reply's quote of the original goes.
enum ChatQuotePlacement { inside, above, below }

/// How date and time separators look.
enum ChatSeparatorStyle { hairline, pill, plain }

/// Layout metrics and colours of one [ChatAppearance], modelled on the real
/// apps (Telegram from its open-source palette and styles).
class ChatStyle {
  const ChatStyle({
    required this.palette,
    required this.avatar,
    required this.avatarShape,
    required this.avatarSize,
    required this.ownAvatar,
    required this.avatarInDirectChats,
    required this.name,
    required this.time,
    required this.quote,
    required this.separator,
    required this.separatorGap,
    required this.radius,
    required this.joinRadius,
    required this.tail,
    required this.padding,
    required this.maxWidth,
    required this.runGap,
    required this.groupGap,
    required this.fontSize,
    required this.ticks,
  });

  factory ChatStyle.of(ChatAppearance appearance, BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = context.radii;
    return switch (appearance) {
      ChatAppearance.worknexus => ChatStyle(
        palette: ChatStylePalette.fromTheme(context.colors),
        avatar: ChatAvatarPlacement.firstOfRun,
        avatarShape: ChatAvatarShape.circle,
        avatarSize: 32,
        ownAvatar: false,
        avatarInDirectChats: true,
        name: ChatNamePlacement.aboveBubble,
        time: ChatTimePlacement.belowContent,
        quote: ChatQuotePlacement.inside,
        separator: ChatSeparatorStyle.hairline,
        separatorGap: null,
        radius: r.lg,
        joinRadius: r.xs,
        tail: null,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        maxWidth: 560,
        runGap: 2,
        groupGap: 16,
        fontSize: 13,
        ticks: false,
      ),
      ChatAppearance.telegram => ChatStyle(
        palette: dark
            ? ChatStylePalette.telegramNight
            : ChatStylePalette.telegramDay,
        avatar: ChatAvatarPlacement.lastOfRun,
        avatarShape: ChatAvatarShape.circle,
        avatarSize: 33,
        ownAvatar: false,
        avatarInDirectChats: false,
        name: ChatNamePlacement.insideBubble,
        time: ChatTimePlacement.insideEnd,
        quote: ChatQuotePlacement.inside,
        separator: ChatSeparatorStyle.pill,
        separatorGap: null,
        radius: 16,
        joinRadius: 6,
        tail: BubbleTailKind.curlBottom,
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
        maxWidth: 480,
        runGap: 2,
        groupGap: 10,
        fontSize: 13.5,
        ticks: true,
      ),
      ChatAppearance.zalo => ChatStyle(
        palette: dark ? ChatStylePalette.zaloDark : ChatStylePalette.zaloLight,
        avatar: ChatAvatarPlacement.firstOfRun,
        avatarShape: ChatAvatarShape.circle,
        avatarSize: 40,
        ownAvatar: false,
        avatarInDirectChats: true,
        name: ChatNamePlacement.insideBubble,
        time: ChatTimePlacement.belowContent,
        quote: ChatQuotePlacement.inside,
        separator: ChatSeparatorStyle.pill,
        separatorGap: null,
        radius: 8,
        joinRadius: 8,
        tail: null,
        padding: const EdgeInsets.all(12),
        maxWidth: 600,
        runGap: 4,
        groupGap: 14,
        fontSize: 14.5,
        ticks: false,
      ),
      ChatAppearance.messenger => ChatStyle(
        palette: dark
            ? ChatStylePalette.messengerDark
            : ChatStylePalette.messengerLight,
        avatar: ChatAvatarPlacement.lastOfRun,
        avatarShape: ChatAvatarShape.circle,
        avatarSize: 28,
        ownAvatar: false,
        avatarInDirectChats: true,
        name: ChatNamePlacement.aboveBubble,
        time: ChatTimePlacement.separators,
        quote: ChatQuotePlacement.above,
        separator: ChatSeparatorStyle.plain,
        separatorGap: const Duration(minutes: 15),
        radius: 18,
        joinRadius: 4,
        tail: null,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        maxWidth: 520,
        runGap: 2,
        groupGap: 12,
        fontSize: 14.5,
        ticks: false,
      ),
      ChatAppearance.wechat => ChatStyle(
        palette: dark
            ? ChatStylePalette.wechatDark
            : ChatStylePalette.wechatLight,
        avatar: ChatAvatarPlacement.everyMessage,
        avatarShape: ChatAvatarShape.roundedSquare,
        avatarSize: 36,
        ownAvatar: true,
        avatarInDirectChats: true,
        name: ChatNamePlacement.aboveBubble,
        time: ChatTimePlacement.separators,
        quote: ChatQuotePlacement.below,
        separator: ChatSeparatorStyle.plain,
        separatorGap: const Duration(minutes: 5),
        radius: 4,
        joinRadius: 4,
        tail: BubbleTailKind.triangleTop,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        maxWidth: 520,
        runGap: 16,
        groupGap: 16,
        fontSize: 14,
        ticks: false,
      ),
    };
  }

  final ChatStylePalette palette;
  final ChatAvatarPlacement avatar;
  final ChatAvatarShape avatarShape;
  final double avatarSize;

  /// Own messages also get an avatar (on the right).
  final bool ownAvatar;

  /// Show avatars in one-to-one chats too (Telegram hides them).
  final bool avatarInDirectChats;
  final ChatNamePlacement name;
  final ChatTimePlacement time;
  final ChatQuotePlacement quote;
  final ChatSeparatorStyle separator;

  /// Pause after which a centered time separator is shown (null = never).
  final Duration? separatorGap;

  /// Bubble corner radius, and the radius where bubbles of a run touch.
  final double radius;
  final double joinRadius;
  final BubbleTailKind? tail;
  final EdgeInsets padding;
  final double maxWidth;

  /// Vertical space between bubbles of one run, and between runs.
  final double runGap;
  final double groupGap;

  /// Message text size.
  final double fontSize;

  /// Show a sent tick after the time of own messages.
  final bool ticks;

  /// Colour for a sender's name.
  Color nameColor(int senderId) {
    final colors = palette.nameColors;
    if (colors == null || colors.isEmpty) return palette.incomingMeta;
    return colors[senderId % colors.length];
  }

  Color bubbleFill({required bool mine}) =>
      mine ? palette.outgoingBubble : palette.incomingBubble;

  Color? bubbleBorder({required bool mine}) =>
      mine ? palette.outgoingBorder : palette.incomingBorder;

  /// Ink for content inside a bubble.
  ChatBubbleInk ink({required bool mine}) {
    final p = palette;
    final bar = mine ? p.outgoingQuoteBar : p.incomingQuoteBar;
    return ChatBubbleInk(
      text: mine ? p.outgoingText : p.incomingText,
      meta: mine ? p.outgoingMeta : p.incomingMeta,
      link: mine ? p.outgoingLink : p.incomingLink,
      quoteBar: bar,
      quoteFill: p.quoteFill ?? bar.withValues(alpha: 0.12),
      tileFill: (mine ? p.outgoingText : p.incomingText).withValues(
        alpha: 0.06,
      ),
      fontSize: fontSize,
    );
  }

  /// Bubble corners for its place in a run: corners where bubbles of a run
  /// touch use [joinRadius]; the tail corner is square so the tail joins.
  BorderRadius corners({
    required bool mine,
    required bool firstOfRun,
    required bool lastOfRun,
    required bool withTail,
  }) {
    final big = Radius.circular(radius);
    final join = Radius.circular(joinRadius);
    Radius corner({required bool top, required bool senderSide}) {
      if (!senderSide) return big;
      if (withTail) {
        if (tail == BubbleTailKind.curlBottom && !top) return Radius.zero;
      }
      final edge = top ? firstOfRun : lastOfRun;
      return edge ? big : join;
    }

    return BorderRadius.only(
      topLeft: corner(top: true, senderSide: !mine),
      bottomLeft: corner(top: false, senderSide: !mine),
      topRight: corner(top: true, senderSide: mine),
      bottomRight: corner(top: false, senderSide: mine),
    );
  }
}
