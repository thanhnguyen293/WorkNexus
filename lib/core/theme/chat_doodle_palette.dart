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
}
