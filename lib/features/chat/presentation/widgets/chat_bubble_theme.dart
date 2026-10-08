import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';

/// Ink for the content of one bubble. Chat styles colour bubbles their own
/// way (Telegram's green outgoing bubble, Messenger's blue one, …), so text,
/// time, links and quotes inside must follow the bubble, not the app theme.
class ChatBubbleInk {
  const ChatBubbleInk({
    required this.text,
    required this.meta,
    required this.link,
    required this.quoteBar,
    required this.quoteFill,
    required this.tileFill,
    Color? quoteSurface,
    this.fontSize = 13,
  }) : quoteSurface = quoteSurface ?? quoteFill;

  /// The app theme's ink, for content outside any styled bubble.
  factory ChatBubbleInk.fromTheme(BuildContext context) {
    final c = context.colors;
    return ChatBubbleInk(
      text: c.textPrimary,
      meta: c.textTertiary,
      link: c.accent,
      quoteBar: c.accent,
      quoteFill: c.background,
      tileFill: c.background,
    );
  }

  final Color text;

  /// Time, sizes, secondary lines.
  final Color meta;

  /// Links and mentions.
  final Color link;

  /// Reply quote: the bar on its left edge and its background.
  final Color quoteBar;
  final Color quoteFill;

  /// What a quote or link card actually shows as its background: [quoteFill]
  /// blended over the bubble and the chat background (opaque), for checking
  /// that coloured text on it stays readable.
  final Color quoteSurface;

  /// Background of icon tiles (link and file cards) inside the bubble.
  final Color tileFill;

  /// Message text size of the active chat style.
  final double fontSize;
}

/// Provides [ChatBubbleInk] to a bubble's content.
class ChatBubbleTheme extends InheritedWidget {
  const ChatBubbleTheme({super.key, required this.ink, required super.child});

  final ChatBubbleInk ink;

  static ChatBubbleInk of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatBubbleTheme>()?.ink ??
      ChatBubbleInk.fromTheme(context);

  @override
  bool updateShouldNotify(ChatBubbleTheme oldWidget) => oldWidget.ink != ink;
}
