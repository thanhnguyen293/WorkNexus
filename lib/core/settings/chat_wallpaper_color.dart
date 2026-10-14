import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// A coloured chat wallpaper as kept in `AppSettings.chatWallpaper`:
/// `tint:<colour>` (the doodle pattern over it) or `solid:<colour>` (the
/// colour alone), where `<colour>` is a preset id (`ChatWallpaperTint.id`) or
/// `#RRGGBB`. Kept in the one wallpaper setting so choosing a colour, the
/// pattern or an image stays a single choice.
@immutable
class ChatWallpaperColor {
  const ChatWallpaperColor(this.color, {this.doodles = true});

  final String color;

  /// Whether the doodle pattern is drawn over the colour.
  final bool doodles;

  static const _tint = 'tint:';
  static const _solid = 'solid:';

  /// The colour [wallpaper] names, or null for any other wallpaper (plain or
  /// an image path — paths never start like these).
  static ChatWallpaperColor? parse(String wallpaper) {
    // The default pattern is the green colour with the pattern over it.
    if (wallpaper == kChatWallpaperPattern) {
      return const ChatWallpaperColor('green');
    }
    for (final (prefix, doodles) in [(_tint, true), (_solid, false)]) {
      if (!wallpaper.startsWith(prefix)) continue;
      final color = wallpaper.substring(prefix.length);
      return color.isEmpty ? null : ChatWallpaperColor(color, doodles: doodles);
    }
    return null;
  }

  /// The setting value.
  String get value => '${doodles ? _tint : _solid}$color';

  ChatWallpaperColor copyWith({String? color, bool? doodles}) =>
      ChatWallpaperColor(color ?? this.color, doodles: doodles ?? this.doodles);

  @override
  bool operator ==(Object other) =>
      other is ChatWallpaperColor &&
      other.color == color &&
      other.doodles == doodles;

  @override
  int get hashCode => Object.hash(color, doodles);
}
