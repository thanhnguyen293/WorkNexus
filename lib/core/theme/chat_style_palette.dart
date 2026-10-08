import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colour tokens of one chat style ([ChatAppearance]) in one brightness.
///
/// Each starts from the real app's colours (Telegram Desktop's palette and
/// night theme, WeChat's PC client, best matches for Messenger and Zalo) and
/// is then tuned for WCAG contrast against its bubble: message text ≥ 7:1
/// (≥ 4.5:1 for white on Messenger's blue), and times, links, sender names,
/// quote headers and separator labels ≥ 4.5:1.
@immutable
class ChatStylePalette {
  const ChatStylePalette({
    required this.background,
    required this.incomingBubble,
    required this.incomingText,
    required this.incomingMeta,
    required this.incomingLink,
    required this.incomingQuoteBar,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.outgoingMeta,
    required this.outgoingLink,
    required this.outgoingQuoteBar,
    required this.separatorText,
    this.incomingBorder,
    this.outgoingBorder,
    this.separatorFill,
    this.nameColors,
    this.outgoingTicks,
    this.quoteFill,
  });

  /// The WorkNexus style follows the app theme.
  factory ChatStylePalette.fromTheme(AppColors c) => ChatStylePalette(
    background: c.background,
    incomingBubble: c.surface,
    incomingText: c.textPrimary,
    incomingMeta: c.textTertiary,
    incomingLink: c.accent,
    incomingQuoteBar: c.accent,
    outgoingBubble: c.selectionFill,
    outgoingText: c.textPrimary,
    outgoingMeta: c.textTertiary,
    outgoingLink: c.accent,
    outgoingQuoteBar: c.accent,
    separatorText: c.textTertiary,
  );

  /// Chat area behind the messages.
  final Color background;

  final Color incomingBubble;
  final Color incomingText;

  /// Time and secondary text in incoming bubbles.
  final Color incomingMeta;
  final Color incomingLink;
  final Color incomingQuoteBar;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color outgoingMeta;
  final Color outgoingLink;
  final Color outgoingQuoteBar;

  /// Bubble outlines (Zalo); null = no border.
  final Color? incomingBorder;
  final Color? outgoingBorder;

  /// Date/time separators: pill fill (null = plain text) and text colour.
  final Color? separatorFill;
  final Color separatorText;

  /// Per-sender name colours (Telegram); null = [incomingMeta].
  final List<Color>? nameColors;

  /// Sent ticks on outgoing bubbles (Telegram); null = none.
  final Color? outgoingTicks;

  /// Quote background; null = the quote bar colour at low opacity.
  final Color? quoteFill;

  static const telegramDay = ChatStylePalette(
    background: Color(0xFFD5DDB8),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF000000),
    incomingMeta: Color(0xFF677887),
    incomingLink: Color(0xFF147CB9),
    incomingQuoteBar: Color(0xFF1B71A3),
    outgoingBubble: Color(0xFFEFFDDE),
    outgoingText: Color(0xFF000000),
    outgoingMeta: Color(0xFF437F3E),
    outgoingLink: Color(0xFF378124),
    outgoingQuoteBar: Color(0xFF377430),
    outgoingTicks: Color(0xFF4AA140),
    separatorFill: Color(0xB32F4426),
    separatorText: Color(0xFFFFFFFF),
    nameColors: [
      Color(0xFFC03D33),
      Color(0xFF3D8623),
      Color(0xFF9A6D04),
      Color(0xFF147CB9),
      Color(0xFF8544D6),
      Color(0xFFCD4073),
      Color(0xFF238194),
      Color(0xFFB85C18),
    ],
  );

  static const telegramNight = ChatStylePalette(
    background: Color(0xFF0E1621),
    incomingBubble: Color(0xFF182533),
    incomingText: Color(0xFFF5F5F5),
    incomingMeta: Color(0xFF7C8C9B),
    incomingLink: Color(0xFF70BAF5),
    incomingQuoteBar: Color(0xFF4CA1DD),
    outgoingBubble: Color(0xFF2B5278),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xFFA8C5E1),
    outgoingLink: Color(0xFF83CAFF),
    outgoingQuoteBar: Color(0xFFB9DFFA),
    outgoingTicks: Color(0xFF6BBFFF),
    separatorFill: Color(0xD5213040),
    separatorText: Color(0xFFFFFFFF),
    nameColors: [
      Color(0xFFFB6169),
      Color(0xFF85DE85),
      Color(0xFFF3BC5C),
      Color(0xFF65BDF3),
      Color(0xFFB48BF2),
      Color(0xFFFF5694),
      Color(0xFF62D4E3),
      Color(0xFFFAA357),
    ],
  );

  static const zaloLight = ChatStylePalette(
    background: Color(0xFFEEF0F3),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF081C36),
    incomingMeta: Color(0xFF637894),
    incomingLink: Color(0xFF0068FF),
    incomingQuoteBar: Color(0xFF0065F7),
    incomingBorder: Color(0xFFD6DBE1),
    outgoingBubble: Color(0xFFD3E5FF),
    outgoingText: Color(0xFF081C36),
    outgoingMeta: Color(0xFF54677E),
    outgoingLink: Color(0xFF005CE2),
    outgoingQuoteBar: Color(0xFF0065F7),
    outgoingBorder: Color(0xFFA9C8F2),
    quoteFill: Color(0xFFF0F4FA),
    separatorFill: Color(0x99FFFFFF),
    separatorText: Color(0xFF5A6D86),
  );

  static const zaloDark = ChatStylePalette(
    background: Color(0xFF16191D),
    incomingBubble: Color(0xFF2A2E33),
    incomingText: Color(0xFFE3E5E8),
    incomingMeta: Color(0xFF8B97A6),
    incomingLink: Color(0xFF4D9BFF),
    incomingQuoteBar: Color(0xFF65A8FF),
    incomingBorder: Color(0xFF353A40),
    outgoingBubble: Color(0xFF1B4A82),
    outgoingText: Color(0xFFF2F5F8),
    outgoingMeta: Color(0xFFA9C1E0),
    outgoingLink: Color(0xFF9CC8FF),
    outgoingQuoteBar: Color(0xFFAED2FF),
    outgoingBorder: Color(0xFF245A99),
    separatorFill: Color(0xFF2A2E33),
    separatorText: Color(0xFFB8C2CE),
  );

  static const messengerLight = ChatStylePalette(
    background: Color(0xFFFFFFFF),
    incomingBubble: Color(0xFFF0F0F0),
    incomingText: Color(0xFF050505),
    incomingMeta: Color(0xFF65676B),
    incomingLink: Color(0xFF0060FD),
    incomingQuoteBar: Color(0xFF616367),
    outgoingBubble: Color(0xFF0866FF),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xFFF5F8FF),
    outgoingLink: Color(0xFFFFFFFF),
    outgoingQuoteBar: Color(0xFF111111),
    separatorText: Color(0xFF65676B),
  );

  static const messengerDark = ChatStylePalette(
    background: Color(0xFF000000),
    incomingBubble: Color(0xFF303030),
    incomingText: Color(0xFFE4E6EB),
    incomingMeta: Color(0xFFB0B3B8),
    incomingLink: Color(0xFF4599FF),
    incomingQuoteBar: Color(0xFFB0B3B8),
    outgoingBubble: Color(0xFF0866FF),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xFFF5F8FF),
    outgoingLink: Color(0xFFFFFFFF),
    outgoingQuoteBar: Color(0xFF111111),
    separatorText: Color(0xFFB0B3B8),
  );

  static const wechatLight = ChatStylePalette(
    background: Color(0xFFEDEDED),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF191919),
    incomingMeta: Color(0xFF767676),
    incomingLink: Color(0xFF576B95),
    incomingQuoteBar: Color(0xFF576B95),
    outgoingBubble: Color(0xFF95EC69),
    outgoingText: Color(0xFF0F170A),
    outgoingMeta: Color(0xFF426730),
    outgoingLink: Color(0xFF2F4F1F),
    outgoingQuoteBar: Color(0xFF2F4F1F),
    quoteFill: Color(0x0F000000),
    separatorText: Color(0xFF6B6B6B),
  );

  static const wechatDark = ChatStylePalette(
    background: Color(0xFF111111),
    incomingBubble: Color(0xFF2C2C2C),
    incomingText: Color(0xFFD5D5D5),
    incomingMeta: Color(0xFF939393),
    incomingLink: Color(0xFF8294AC),
    incomingQuoteBar: Color(0xFF7E91AA),
    outgoingBubble: Color(0xFF3EB575),
    outgoingText: Color(0xFF06120B),
    outgoingMeta: Color(0xFF163E28),
    outgoingLink: Color(0xFF0B3320),
    outgoingQuoteBar: Color(0xFF0B3320),
    quoteFill: Color(0x14000000),
    separatorText: Color(0xFF7C7C7C),
  );
}
