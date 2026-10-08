import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'contrast.dart';

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
    this.outgoingQuoteFill,
    this.outsideQuoteFill,
    this.outsideQuoteText,
    this.wallpaper,
    this.wallpaperInk,
  });

  /// The default style follows the app theme. Secondary text uses the
  /// theme's secondary (not tertiary) ink, which keeps ≥ 4.5:1 on the tinted
  /// own bubble; quotes and link cards are neutral — grey in incoming,
  /// white in own bubbles — so they stand apart without a second tint.
  factory ChatStylePalette.fromTheme(AppColors c) => ChatStylePalette(
    background: c.background,
    incomingBubble: c.surface,
    incomingText: c.textPrimary,
    incomingMeta: c.textSecondary,
    incomingLink: c.accent,
    incomingQuoteBar: c.accent,
    outgoingBubble: c.selectionFill,
    outgoingText: c.textPrimary,
    outgoingMeta: c.textSecondary,
    // The accent on the accent-tinted own bubble falls a little short.
    outgoingLink: readableOn(
      c.accent,
      Color.alphaBlend(c.selectionFill, c.background),
      towards: c.textPrimary,
    ),
    outgoingQuoteBar: c.accent,
    quoteFill: c.background,
    outgoingQuoteFill: c.surface,
    separatorText: c.textSecondary,
  );

  /// This palette with own bubbles in the app's accent [c] instead of the
  /// messenger's colour. [solid] (Messenger) fills them with the accent and
  /// light text; otherwise they get an accent tint over the incoming bubble
  /// with normal text, so contrast stays as in the theme.
  ChatStylePalette withPrimaryBubbles(
    AppColors c, {
    required bool solid,
    required bool dark,
  }) {
    final tint = Color.alphaBlend(
      c.accent.withValues(alpha: dark ? 0.32 : 0.16),
      incomingBubble,
    );
    return ChatStylePalette(
      background: background,
      incomingBubble: incomingBubble,
      incomingText: incomingText,
      incomingMeta: incomingMeta,
      incomingLink: incomingLink,
      incomingQuoteBar: incomingQuoteBar,
      incomingBorder: incomingBorder,
      outgoingBubble: solid ? _readableFill(c.accent, c.onAccent) : tint,
      outgoingText: solid ? c.onAccent : incomingText,
      outgoingMeta: solid ? c.onAccent.withValues(alpha: 0.85) : incomingMeta,
      outgoingLink: solid ? c.onAccent : c.accent,
      outgoingQuoteBar: solid ? c.onAccent : c.accent,
      outgoingBorder: outgoingBorder == null
          ? null
          : Color.alphaBlend(c.accent.withValues(alpha: 0.35), incomingBubble),
      outgoingTicks: outgoingTicks == null ? null : c.accent,
      separatorFill: separatorFill,
      separatorText: separatorText,
      nameColors: nameColors,
      quoteFill: quoteFill,
      // outgoingQuoteFill is left out: it suits the messenger's own bubble,
      // not the accent one.
      outsideQuoteFill: outsideQuoteFill,
      outsideQuoteText: outsideQuoteText,
      wallpaper: wallpaper,
      wallpaperInk: wallpaperInk,
    );
  }

  /// [fill] darkened just enough for [ink] to read at 4.5:1 (a dark theme's
  /// light accent under white text would not).
  static Color _readableFill(Color fill, Color ink) {
    var out = fill;
    for (
      var shade = 0.08;
      contrastRatio(ink, out) < 4.5 && shade <= 0.6;
      shade += 0.08
    ) {
      out = Color.alphaBlend(_black.withValues(alpha: shade), fill);
    }
    return out;
  }

  static const _black = Color(0xFF000000);

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

  /// Quote/card background in outgoing bubbles, when it differs from
  /// [quoteFill] (the default style: white on its tinted own bubbles).
  final Color? outgoingQuoteFill;

  /// A reply quote shown outside the bubble (Messenger, WeChat): its box and
  /// text; null = the incoming bubble colour and [incomingMeta].
  final Color? outsideQuoteFill;
  final Color? outsideQuoteText;

  /// A wallpaper behind the messages (Telegram): the colours of a soft
  /// four-corner gradient — top left, top right, bottom right, bottom left
  /// — with [background] as their average. Null = flat [background].
  final List<Color>? wallpaper;

  /// Colour of the doodle pattern drawn over [wallpaper]; null = none.
  final Color? wallpaperInk;

  /// Quote/card background inside a dark or saturated bubble: a darker
  /// inset keeps light text readable (a light tint would wash it out).
  static const darkInset = Color(0x2E000000);

  static const telegramDay = ChatStylePalette(
    background: Color(0xFFA9C08E),
    // Telegram's default gradient wallpaper (green / sand).
    wallpaper: [
      Color(0xFFDBDDBB),
      Color(0xFF6BA587),
      Color(0xFFD5D88D),
      Color(0xFF88B884),
    ],
    wallpaperInk: Color(0x1F1D3A1A),
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
    separatorFill: Color(0xB3405A33),
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
    background: Color(0xFF0B121B),
    wallpaper: [
      Color(0xFF14232F),
      Color(0xFF0B141D),
      Color(0xFF1A2A2C),
      Color(0xFF0E1A22),
    ],
    wallpaperInk: Color(0x14FFFFFF),
    incomingBubble: Color(0xFF1E2C3A),
    incomingText: Color(0xFFF5F5F5),
    incomingMeta: Color(0xFF8493A1),
    incomingLink: Color(0xFF70BAF5),
    incomingQuoteBar: Color(0xFF429BDB),
    outgoingBubble: Color(0xFF2B5278),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xFFA8C5E1),
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
    incomingQuoteBar: Color(0xFF4D9BFF),
    incomingBorder: Color(0xFF353A40),
    outgoingBubble: Color(0xFF1B4A82),
    outgoingText: Color(0xFFF2F5F8),
    outgoingMeta: Color(0xFFA9C1E0),
    outgoingLink: Color(0xFF9CC8FF),
    outgoingQuoteBar: Color(0xFF9CC8FF),
    outgoingBorder: Color(0xFF245A99),
    separatorFill: Color(0xFF2A2E33),
    separatorText: Color(0xFFB8C2CE),
  );

  static const messengerLight = ChatStylePalette(
    background: Color(0xFFFFFFFF),
    incomingBubble: Color(0xFFEBECEF),
    incomingText: Color(0xFF050505),
    incomingMeta: Color(0xFF65676B),
    incomingLink: Color(0xFF005EF7),
    incomingQuoteBar: Color(0xFF5E6064),
    outgoingBubble: Color(0xFF0866FF),
    outgoingText: Color(0xFFFFFFFF),
    outgoingMeta: Color(0xFFF5F8FF),
    outgoingLink: Color(0xFFFFFFFF),
    outgoingQuoteBar: Color(0xFFFFFFFF),
    // A deep navy card on the blue own bubble: state colours (green, red,
    // purple) then read without being washed out to white.
    outgoingQuoteFill: Color(0x66001A4D),
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
    outgoingQuoteBar: Color(0xFFFFFFFF),
    // A deep navy card on the blue own bubble: state colours (green, red,
    // purple) then read without being washed out to white.
    outgoingQuoteFill: Color(0x66001A4D),
    separatorText: Color(0xFFB0B3B8),
  );

  static const wechatLight = ChatStylePalette(
    background: Color(0xFFE8E8E8),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF191919),
    incomingMeta: Color(0xFF767676),
    incomingLink: Color(0xFF576B95),
    incomingQuoteBar: Color(0xFF576B95),
    outgoingBubble: Color(0xFFADD897),
    outgoingText: Color(0xFF0F170A),
    outgoingMeta: Color(0xFF3D5E2C),
    outgoingLink: Color(0xFF2F4F1F),
    outgoingQuoteBar: Color(0xFF2F4F1F),
    quoteFill: Color(0x0F000000),
    // A pale wash on the green own bubble: a dark tint turns it muddy.
    outgoingQuoteFill: Color(0x99FFFFFF),
    separatorText: Color(0xFF686868),
    outsideQuoteFill: Color(0xFFDADADA),
    outsideQuoteText: Color(0xFF4C4C4C),
  );

  static const wechatDark = ChatStylePalette(
    background: Color(0xFF111111),
    incomingBubble: Color(0xFF2C2C2C),
    incomingText: Color(0xFFD5D5D5),
    incomingMeta: Color(0xFF939393),
    incomingLink: Color(0xFF8294AC),
    incomingQuoteBar: Color(0xFF7E91AA),
    outgoingBubble: Color(0xFF37A169),
    outgoingText: Color(0xFF000000),
    outgoingMeta: Color(0xFF102E1E),
    outgoingLink: Color(0xFF0A2E1D),
    outgoingQuoteBar: Color(0xFF071F13),
    quoteFill: Color(0x14000000),
    outgoingQuoteFill: Color(0x4DFFFFFF),
    separatorText: Color(0xFF7C7C7C),
    outsideQuoteFill: Color(0xFF262626),
    outsideQuoteText: Color(0xFFB2B2B2),
  );
}
