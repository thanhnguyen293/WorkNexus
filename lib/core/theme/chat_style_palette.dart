import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colour tokens of one chat style ([ChatAppearance]) in one brightness.
///
/// The Telegram values are Telegram Desktop's own palette (lib_ui
/// `colors.palette` and the shipped night theme). WeChat's come from a
/// published replica plus the PC client; Messenger's and Zalo's are best
/// matches to the apps (no public theme files exist).
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
    incomingMeta: Color(0xFFA0ACB6),
    incomingLink: Color(0xFF168ACD),
    incomingQuoteBar: Color(0xFF37A1DE),
    outgoingBubble: Color(0xFFEFFDDE),
    outgoingText: Color(0xFF000000),
    outgoingMeta: Color(0xFF6DB566),
    outgoingLink: Color(0xFF45A32D),
    outgoingQuoteBar: Color(0xFF5EB854),
    outgoingTicks: Color(0xFF57B84C),
    separatorFill: Color(0x7F517C41),
    separatorText: Color(0xFFFFFFFF),
    nameColors: [
      Color(0xFFC03D33),
      Color(0xFF4FAD2D),
      Color(0xFFD09306),
      Color(0xFF168ACD),
      Color(0xFF8544D6),
      Color(0xFFCD4073),
      Color(0xFF2996AD),
      Color(0xFFCE671B),
    ],
  );

  static const telegramNight = ChatStylePalette(
    background: Color(0xFF0E1621),
    incomingBubble: Color(0xFF182533),
    incomingText: Color(0xFFF5F5F5),
    incomingMeta: Color(0xFF6D7F8F),
    incomingLink: Color(0xFF70BAF5),
    incomingQuoteBar: Color(0xFF429BDB),
    outgoingBubble: Color(0xFF2B5278),
    outgoingText: Color(0xFFE4ECF2),
    outgoingMeta: Color(0xFF7DA8D3),
    outgoingLink: Color(0xFF83CAFF),
    outgoingQuoteBar: Color(0xFF65B9F4),
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
    background: Color(0xFFE2E9F1),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF081C36),
    incomingMeta: Color(0xFF7589A3),
    incomingLink: Color(0xFF0068FF),
    incomingQuoteBar: Color(0xFF0068FF),
    incomingBorder: Color(0xFFE1E4EA),
    outgoingBubble: Color(0xFFE5EFFF),
    outgoingText: Color(0xFF081C36),
    outgoingMeta: Color(0xFF7589A3),
    outgoingLink: Color(0xFF0068FF),
    outgoingQuoteBar: Color(0xFF0068FF),
    outgoingBorder: Color(0xFFC7E0FF),
    quoteFill: Color(0xFFF0F4FA),
    separatorFill: Color(0x33000000),
    separatorText: Color(0xFFFFFFFF),
  );

  static const zaloDark = ChatStylePalette(
    background: Color(0xFF16191D),
    incomingBubble: Color(0xFF2A2E33),
    incomingText: Color(0xFFE3E5E8),
    incomingMeta: Color(0xFF8B97A6),
    incomingLink: Color(0xFF4D9BFF),
    incomingQuoteBar: Color(0xFF4D9BFF),
    incomingBorder: Color(0xFF353A40),
    outgoingBubble: Color(0xFF1B4A82),
    outgoingText: Color(0xFFE3E5E8),
    outgoingMeta: Color(0xFFA9C1E0),
    outgoingLink: Color(0xFF9CC8FF),
    outgoingQuoteBar: Color(0xFF9CC8FF),
    outgoingBorder: Color(0xFF245A99),
    separatorFill: Color(0x40000000),
    separatorText: Color(0xFFE3E5E8),
  );

  static const messengerLight = ChatStylePalette(
    background: Color(0xFFFFFFFF),
    incomingBubble: Color(0xFFF0F0F0),
    incomingText: Color(0xFF050505),
    incomingMeta: Color(0xFF65676B),
    incomingLink: Color(0xFF0A7CFF),
    incomingQuoteBar: Color(0xFFBCC0C4),
    outgoingBubble: Color(0xFF0A7CFF),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xCCFFFFFF),
    outgoingLink: Color(0xFFFFFFFF),
    outgoingQuoteBar: Color(0xCCFFFFFF),
    separatorText: Color(0xFF65676B),
  );

  static const messengerDark = ChatStylePalette(
    background: Color(0xFF000000),
    incomingBubble: Color(0xFF303030),
    incomingText: Color(0xFFE4E6EB),
    incomingMeta: Color(0xFFB0B3B8),
    incomingLink: Color(0xFF4599FF),
    incomingQuoteBar: Color(0xFF5A5C5F),
    outgoingBubble: Color(0xFF0A7CFF),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xCCFFFFFF),
    outgoingLink: Color(0xFFFFFFFF),
    outgoingQuoteBar: Color(0xCCFFFFFF),
    separatorText: Color(0xFFB0B3B8),
  );

  static const wechatLight = ChatStylePalette(
    background: Color(0xFFF5F5F5),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF191919),
    incomingMeta: Color(0xFF888888),
    incomingLink: Color(0xFF576B95),
    incomingQuoteBar: Color(0xFFE8E8E8),
    outgoingBubble: Color(0xFF95EC69),
    outgoingText: Color(0xFF0F170A),
    outgoingMeta: Color(0xFF4F7A39),
    outgoingLink: Color(0xFF3B5A2B),
    outgoingQuoteBar: Color(0xFFE8E8E8),
    quoteFill: Color(0xFFE8E8E8),
    separatorText: Color(0xFFB2B2B2),
  );

  static const wechatDark = ChatStylePalette(
    background: Color(0xFF191919),
    incomingBubble: Color(0xFF2C2C2C),
    incomingText: Color(0xFFD5D5D5),
    incomingMeta: Color(0xFF8C8C8C),
    incomingLink: Color(0xFF7D90A9),
    incomingQuoteBar: Color(0xFF262626),
    outgoingBubble: Color(0xFF3EB575),
    outgoingText: Color(0xFF06120B),
    outgoingMeta: Color(0xFF1C4F33),
    outgoingLink: Color(0xFF0B3320),
    outgoingQuoteBar: Color(0xFF262626),
    quoteFill: Color(0xFF262626),
    separatorText: Color(0xFF6B6B6B),
  );
}
