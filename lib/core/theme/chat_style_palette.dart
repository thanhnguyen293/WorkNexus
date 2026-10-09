import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'contrast.dart';
part 'chat_style_palette_presets.dart';

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
  });

  /// The default style follows the app theme. Secondary text uses the
  /// theme's secondary (not tertiary) ink, which keeps ≥ 4.5:1 on the tinted
  /// own bubble; quotes and link cards are neutral — grey in incoming,
  /// white in own bubbles — so they stand apart without a second tint.
  factory ChatStylePalette.fromTheme(AppColors c) {
    // `card` (white in light mode) rather than `surface`: the sidebar grey
    // sits too close to the chat background for the bubble to stand out. The
    // own bubble is an accent tint over it, strong enough to read against the
    // background by hue as well as lightness.
    // A dark theme gets a weaker tint, or secondary text on it drops below 4.5:1.
    final dark = c.background.computeLuminance() < 0.2;
    final ownBubble = Color.alphaBlend(
      c.accent.withValues(alpha: dark ? 0.16 : 0.26),
      c.card,
    );
    return ChatStylePalette(
      background: c.background,
      incomingBubble: c.card,
      incomingText: c.textPrimary,
      incomingMeta: c.textSecondary,
      incomingLink: c.accent,
      incomingQuoteBar: c.accent,
      // Opaque, so a wallpaper does not show through and shift its colour.
      outgoingBubble: ownBubble,
      outgoingText: c.textPrimary,
      outgoingMeta: c.textSecondary,
      // The accent on the accent-tinted own bubble falls a little short.
      outgoingLink: readableOn(c.accent, ownBubble, towards: c.textPrimary),
      outgoingQuoteBar: c.accent,
      quoteFill: c.background,
      outgoingQuoteFill: c.surface,
      separatorText: c.textSecondary,
    );
  }

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
    );
  }

  /// This palette over another chat background: every style shows on the
  /// one background the user picked (see the chat wallpaper setting).
  ChatStylePalette withBackground(Color background) => ChatStylePalette(
    background: background,
    incomingBubble: incomingBubble,
    incomingText: incomingText,
    incomingMeta: incomingMeta,
    incomingLink: incomingLink,
    incomingQuoteBar: incomingQuoteBar,
    outgoingBubble: outgoingBubble,
    outgoingText: outgoingText,
    outgoingMeta: outgoingMeta,
    outgoingLink: outgoingLink,
    outgoingQuoteBar: outgoingQuoteBar,
    separatorText: separatorText,
    incomingBorder: incomingBorder,
    outgoingBorder: outgoingBorder,
    separatorFill: separatorFill,
    nameColors: nameColors,
    outgoingTicks: outgoingTicks,
    quoteFill: quoteFill,
    outgoingQuoteFill: outgoingQuoteFill,
    outsideQuoteFill: outsideQuoteFill,
    outsideQuoteText: outsideQuoteText,
  );

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

  /// Quote/card background inside a dark or saturated bubble: a darker
  /// inset keeps light text readable (a light tint would wash it out).
  static const darkInset = Color(0x2E000000);

  static const telegramDay = _telegramDay;
  static const telegramNight = _telegramNight;
  static const zaloLight = _zaloLight;
  static const zaloDark = _zaloDark;
  static const messengerLight = _messengerLight;
  static const messengerDark = _messengerDark;
  static const wechatLight = _wechatLight;
  static const wechatDark = _wechatDark;

  /// The TBChat client's bubbles (tbchat_socialfi `PrimaryColorsApi.bubbleColor`
  /// / `otherSideBubbleColor`, a 6% black hairline): pale green own, white
  /// other; text black, secondary text black at 65% (made opaque); quote
  /// bars the app's green. Links use a darker green, which reads on both.
  static const tbchatLight = _tbchatLight;

  /// TBChat's dark bubbles: deep green own, slate other, a 12% white
  /// hairline; text white, secondary white at 65% (made opaque).
  static const tbchatDark = _tbchatDark;
}
