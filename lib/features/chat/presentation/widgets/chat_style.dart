import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/chat_style_palette.dart';
import 'bubble_tail.dart';
import 'chat_avatar.dart';
import 'chat_bubble_theme.dart';
import 'chat_style_specs.dart';

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

  /// The style the user picked, rebuilt when it or its colours change.
  static ChatStyle watch(WidgetRef ref, BuildContext context) {
    final (appearance, primary) = ref.watch(
      appSettingsProvider.select(
        (s) => (s.chatAppearance, s.chatPrimaryBubbles),
      ),
    );
    return ChatStyle.of(appearance, context, primaryBubbles: primary);
  }

  /// [primaryBubbles] gives the messenger styles' own bubbles the app's
  /// accent (the default style already follows the theme).
  factory ChatStyle.of(
    ChatAppearance appearance,
    BuildContext context, {
    bool primaryBubbles = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = chatStyleSpec(appearance, context, dark: dark);
    if (!primaryBubbles || appearance == ChatAppearance.worknexus) {
      return style;
    }
    return style.withPalette(
      style.palette.withPrimaryBubbles(
        context.colors,
        solid: appearance == ChatAppearance.messenger,
        dark: dark,
      ),
    );
  }

  /// This style with other colours (e.g. own bubbles in the accent).
  ChatStyle withPalette(ChatStylePalette palette) => ChatStyle(
    palette: palette,
    avatar: avatar,
    avatarShape: avatarShape,
    avatarSize: avatarSize,
    ownAvatar: ownAvatar,
    avatarInDirectChats: avatarInDirectChats,
    name: name,
    time: time,
    quote: quote,
    separator: separator,
    separatorGap: separatorGap,
    radius: radius,
    joinRadius: joinRadius,
    tail: tail,
    padding: padding,
    maxWidth: maxWidth,
    runGap: runGap,
    groupGap: groupGap,
    fontSize: fontSize,
    ticks: ticks,
  );

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
    final text = mine ? p.outgoingText : p.incomingText;
    // Light ink on a dark or saturated bubble (Messenger's blue, night
    // themes) needs a stronger tint for quotes and tiles to read as a
    // separate area; dark ink on a pale bubble needs only a hint.
    final strong =
        Color.alphaBlend(
          bubbleFill(mine: mine),
          p.background,
        ).computeLuminance() <
        0.2;
    return ChatBubbleInk(
      text: text,
      meta: mine ? p.outgoingMeta : p.incomingMeta,
      link: mine ? p.outgoingLink : p.incomingLink,
      quoteBar: bar,
      quoteFill:
          p.quoteFill ??
          (strong ? ChatStylePalette.darkInset : bar.withValues(alpha: 0.12)),
      tileFill: text.withValues(alpha: strong ? 0.16 : 0.06),
      fontSize: fontSize,
    );
  }

  /// Ink for a reply quote drawn outside the bubble, on the chat background
  /// (Messenger above, WeChat below): a muted grey box, not the app accent,
  /// so it reads as context rather than as a message of its own.
  ChatBubbleInk outsideQuoteInk() {
    final p = palette;
    final text = p.outsideQuoteText ?? p.incomingMeta;
    return ChatBubbleInk(
      text: text,
      meta: text,
      link: p.incomingLink,
      quoteBar: text,
      quoteFill: p.outsideQuoteFill ?? p.incomingBubble,
      tileFill: text.withValues(alpha: 0.06),
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
