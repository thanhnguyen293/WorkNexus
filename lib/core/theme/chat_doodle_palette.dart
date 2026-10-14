import 'package:flutter/material.dart';

/// Colours of the "pattern" chat wallpaper: a soft four-corner gradient
/// ([corners]: top left, top right, bottom right, bottom left, over [base])
/// under a tiled doodle pattern drawn in [ink]. Shared by every chat style.
@immutable
class ChatDoodlePalette {
  const ChatDoodlePalette({
    required this.base,
    required this.corners,
    required this.ink,
  });

  final Color base;
  final List<Color> corners;
  final Color ink;

  /// Telegram's default gradient wallpaper (green / sand).
  static const day = ChatDoodlePalette(
    base: Color(0xFFA9C08E),
    corners: [
      Color(0xFFDBDDBB),
      Color(0xFF6BA587),
      Color(0xFFD5D88D),
      Color(0xFF88B884),
    ],
    ink: Color(0x1F1D3A1A),
  );

  static const night = ChatDoodlePalette(
    base: Color(0xFF0B121B),
    corners: [
      Color(0xFF14232F),
      Color(0xFF0B141D),
      Color(0xFF1A2A2C),
      Color(0xFF0E1A22),
    ],
    ink: Color(0x14FFFFFF),
  );

  static ChatDoodlePalette of(Brightness brightness) =>
      brightness == Brightness.dark ? night : day;

  /// The wallpaper for a chosen colour: preset [ChatWallpaperTint.id] (in the
  /// theme's shade) or `#RRGGBB` (as picked, in either theme). Null when
  /// [color] is neither.
  static ChatDoodlePalette? forColor(String color, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (color == ChatWallpaperTint.green.id) return dark ? night : day;
    for (final tint in ChatWallpaperTint.presets) {
      if (tint.id == color) return fromColor(dark ? tint.night : tint.day);
    }
    final hex = color.replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return fromColor(Color(0xFF000000 | int.parse(hex, radix: 16)));
  }

  /// A doodle wallpaper around [base]: corners a shade lighter and darker so
  /// the gradient stays soft, and doodles a deep shade of the same hue on a
  /// light colour (a faint white on a dark one), like the default.
  static ChatDoodlePalette fromColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    final light = hsl.lightness > 0.45;
    // Dark colours show a shift sooner, so they move less.
    final step = light ? 0.08 : 0.035;
    Color shade(double lightness, double hue) => hsl
        .withLightness((hsl.lightness + lightness).clamp(0, 1))
        .withHue((hsl.hue + hue) % 360)
        .toColor();
    return ChatDoodlePalette(
      base: base,
      corners: [
        shade(step, 0),
        shade(-step, 8),
        shade(step * 0.7, -8),
        shade(-step * 0.5, 4),
      ],
      ink: light
          ? hsl
                .withLightness((hsl.lightness - 0.5).clamp(0, 1))
                .toColor()
                .withValues(alpha: 0.14)
          : const Color(0x14FFFFFF),
    );
  }
}

/// A preset chat wallpaper colour, with its shade for a light and a dark
/// theme so messages stay readable over it.
@immutable
class ChatWallpaperTint {
  const ChatWallpaperTint(this.id, {required this.day, required this.night});

  /// Stored in the wallpaper setting; never shown.
  final String id;
  final Color day;
  final Color night;

  Color of(Brightness brightness) =>
      brightness == Brightness.dark ? night : day;

  /// The default doodle wallpaper's green ([ChatDoodlePalette.day]/[night]).
  static const green = ChatWallpaperTint(
    'green',
    day: Color(0xFFA9C08E),
    night: Color(0xFF0B121B),
  );

  static const presets = [
    green,
    ChatWallpaperTint('blue', day: Color(0xFF9DB9D9), night: Color(0xFF0F1A2B)),
    ChatWallpaperTint('teal', day: Color(0xFF92CBC4), night: Color(0xFF0D2224)),
    ChatWallpaperTint(
      'purple',
      day: Color(0xFFB7A6D6),
      night: Color(0xFF1A1529),
    ),
    ChatWallpaperTint('pink', day: Color(0xFFE0A9BE), night: Color(0xFF2A1520)),
    ChatWallpaperTint(
      'orange',
      day: Color(0xFFE6C29A),
      night: Color(0xFF2A1D10),
    ),
    ChatWallpaperTint('sand', day: Color(0xFFD9CFB4), night: Color(0xFF1F1B12)),
    ChatWallpaperTint('gray', day: Color(0xFFC4C7CC), night: Color(0xFF16181C)),
  ];
}
