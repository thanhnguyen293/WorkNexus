import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/chat_wallpaper_color.dart';
import 'package:work_nexus/core/theme/chat_doodle_palette.dart';

void main() {
  group('ChatWallpaperColor', () {
    test('reads and writes a colour with or without the pattern', () {
      expect(
        ChatWallpaperColor.parse('tint:blue'),
        const ChatWallpaperColor('blue'),
      );
      expect(
        ChatWallpaperColor.parse('solid:#1A2B3C'),
        const ChatWallpaperColor('#1A2B3C', doodles: false),
      );
      expect(
        const ChatWallpaperColor('blue', doodles: false).value,
        'solid:blue',
      );
      expect(const ChatWallpaperColor('#1A2B3C').value, 'tint:#1A2B3C');
    });

    test('the default pattern is green with the pattern', () {
      expect(
        ChatWallpaperColor.parse('pattern'),
        const ChatWallpaperColor('green'),
      );
    });

    test('other wallpapers are not colours', () {
      for (final other in ['', 'none', '/Users/me/wall.png', 'tint:']) {
        expect(ChatWallpaperColor.parse(other), isNull, reason: other);
      }
    });
  });

  group('ChatDoodlePalette.forColor', () {
    test('green is the default pattern, in the theme\'s shade', () {
      expect(
        ChatDoodlePalette.forColor('green', Brightness.light),
        ChatDoodlePalette.day,
      );
      expect(
        ChatDoodlePalette.forColor('green', Brightness.dark),
        ChatDoodlePalette.night,
      );
    });

    test('a preset follows the theme; a picked colour stays as picked', () {
      expect(
        ChatDoodlePalette.forColor('blue', Brightness.dark)?.base,
        const Color(0xFF0F1A2B),
      );
      expect(
        ChatDoodlePalette.forColor('#1A2B3C', Brightness.light)?.base,
        const Color(0xFF1A2B3C),
      );
      expect(ChatDoodlePalette.forColor('nope', Brightness.light), isNull);
    });

    test(
      'doodles are dark on a light colour and faint white on a dark one',
      () {
        final light = ChatDoodlePalette.fromColor(const Color(0xFFE0A9BE));
        final dark = ChatDoodlePalette.fromColor(const Color(0xFF0F1A2B));
        expect(light.ink.computeLuminance(), lessThan(0.2));
        expect(dark.ink, const Color(0x14FFFFFF));
        expect(light.corners, hasLength(4));
      },
    );
  });
}
