import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/chat_doodle_palette.dart';

/// Whether the user's chat background is a picture (the pattern or an
/// image) rather than the plain app background — then separators need a
/// fill of their own to stay readable.
bool chatWallpaperIsPicture(String wallpaper) =>
    wallpaper.isNotEmpty && wallpaper != kChatWallpaperPlain;

/// The messages' background, shared by every chat style: the app's plain
/// background, the doodle pattern, or a picked image darkened by
/// `chatWallpaperDim` so separators and times stay readable over it.
class ChatBackground extends ConsumerWidget {
  const ChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (wallpaper, dim) = ref.watch(
      appSettingsProvider.select((s) => (s.chatWallpaper, s.chatWallpaperDim)),
    );
    final plain = ColoredBox(color: context.colors.background);
    if (!chatWallpaperIsPicture(wallpaper)) {
      return ColoredBox(color: context.colors.background, child: child);
    }
    if (wallpaper == kChatWallpaperPattern) {
      return ChatWallpaper(
        doodle: ChatDoodlePalette.of(Theme.of(context).brightness),
        child: child,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Image.file(
            File(wallpaper),
            fit: BoxFit.cover,
            // Decoded once at the screen's width, not the photo's: sized to
            // the area instead, every step of a window resize decoded it
            // again and the background blinked while each decode ran.
            cacheWidth: View.of(context).display.size.width.round(),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => plain,
          ),
        ),
        if (dim > 0)
          ColoredBox(color: context.colors.scrim.withValues(alpha: dim)),
        child,
      ],
    );
  }
}

/// The doodle pattern background: a soft four-corner gradient under a
/// tiled doodle pattern. Drawn once and cached (RepaintBoundary), so
/// scrolling the messages over it does not repaint it.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({
    super.key,
    required this.doodle,
    required this.child,
    this.scale = 1,
  });

  final ChatDoodlePalette doodle;
  final Widget child;

  /// Pattern size (previews draw it smaller).
  final double scale;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          painter: _WallpaperPainter(
            base: doodle.base,
            corners: doodle.corners,
            ink: doodle.ink,
            scale: scale,
          ),
        ),
      ),
      child,
    ],
  );
}

/// Doodles of the pattern: work and everyday things, as Lucide's light
/// line icons — one thin stroke weight, like Telegram's doodles.
const _doodles = <IconData>[
  LucideIcons.messageCircle300,
  LucideIcons.coffee300,
  LucideIcons.rocket300,
  LucideIcons.lightbulb300,
  LucideIcons.bug300,
  LucideIcons.music300,
  LucideIcons.heart300,
  LucideIcons.star300,
  LucideIcons.camera300,
  LucideIcons.headphones300,
  LucideIcons.flower300,
  LucideIcons.cake300,
  LucideIcons.plane300,
  LucideIcons.code300,
  LucideIcons.pin300,
  LucideIcons.pawPrint300,
  LucideIcons.cloud300,
  LucideIcons.smile300,
  LucideIcons.sailboat300,
  LucideIcons.partyPopper300,
  LucideIcons.send300,
  LucideIcons.gamepad2300,
  LucideIcons.bike300,
  LucideIcons.umbrella300,
  LucideIcons.moonStar300,
  LucideIcons.book300,
  LucideIcons.pencil300,
  LucideIcons.gift300,
  LucideIcons.balloon300,
  LucideIcons.leaf300,
  LucideIcons.orbit300,
  LucideIcons.ghost300,
  LucideIcons.treePalm300,
  LucideIcons.pizza300,
  LucideIcons.iceCream300,
  LucideIcons.mail300,
  LucideIcons.palette300,
  LucideIcons.guitar300,
  LucideIcons.flower2300,
  LucideIcons.fish300,
  LucideIcons.anchor300,
  LucideIcons.cat300,
  LucideIcons.bell300,
  LucideIcons.laptop300,
];

/// Side of one pattern tile and how many doodles fit across it. Large and
/// dense, so the repeat is hard to spot.
const double _kTile = 448;
const int _kCells = 8;

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter({
    required this.base,
    required this.corners,
    required this.ink,
    required this.scale,
  });

  final Color base;
  final List<Color> corners;
  final Color? ink;
  final double scale;

  static const _cornerAlignments = [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomRight,
    Alignment.bottomLeft,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    // Each corner's colour fades out towards the others, which blends them
    // like Telegram's four-point gradient.
    for (final (i, color) in corners.indexed) {
      final shader = RadialGradient(
        center: _cornerAlignments[i],
        radius: 1.3,
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    final ink = this.ink;
    if (ink != null) _paintDoodles(canvas, size, ink);
  }

  void _paintDoodles(Canvas canvas, Size size, Color ink) {
    final tile = _kTile * scale;
    final cell = tile / _kCells;
    // The same arrangement in every tile; fixed seed so it never shifts.
    final random = math.Random(7);
    // Each doodle before any repeats, so neighbours rarely match.
    final order = [..._doodles]..shuffle(random);
    final marks = [
      for (var row = 0; row < _kCells; row++)
        for (var col = 0; col < _kCells; col++)
          (
            icon: order[(row * _kCells + col) % order.length],
            at: Offset(
              (col + 0.3 + random.nextDouble() * 0.4) * cell,
              (row + 0.3 + random.nextDouble() * 0.4) * cell,
            ),
            angle: (random.nextDouble() - 0.5) * 0.7,
            size: cell * (0.5 + random.nextDouble() * 0.1),
          ),
    ];
    final painters = [
      for (final m in marks)
        TextPainter(
          text: TextSpan(
            text: String.fromCharCode(m.icon.codePoint),
            style: TextStyle(
              fontFamily: m.icon.fontFamily,
              package: m.icon.fontPackage,
              fontSize: m.size,
              color: ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        for (final (i, m) in marks.indexed) {
          final p = painters[i];
          canvas
            ..save()
            ..translate(x + m.at.dx, y + m.at.dy)
            ..rotate(m.angle);
          p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
          canvas.restore();
        }
      }
    }
    for (final p in painters) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.base != base ||
      old.ink != ink ||
      old.scale != scale ||
      !_sameColors(old.corners, corners);

  static bool _sameColors(List<Color> a, List<Color> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);
}
