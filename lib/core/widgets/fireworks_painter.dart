import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../util/fireworks.dart';

/// Paints a firework show at [t] (0–1). Each spark is a soft glow round a
/// small core that starts [hot] (near white) and cools to its palette colour,
/// trailing a tail that tapers and fades back towards its burst.
class FireworksPainter extends CustomPainter {
  FireworksPainter({
    required this.sparks,
    required this.t,
    required this.palette,
    required this.hot,
  });

  final List<Spark> sparks;
  final double t;
  final List<Color> palette;
  final Color hot;

  /// The tail's length (in show time) and how many pieces draw it: more
  /// pieces make a smoother taper.
  static const _tail = 0.035;
  static const _tailPieces = 5;

  static final _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
  static final _core = Paint();
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in sparks) {
      final now = sparkAt(spark, t);
      if (now == null) continue;
      final colour = palette[spark.colour % palette.length];
      // Sparks twinkle out of step with each other as they fade.
      final twinkle = now.life < 0.4
          ? 1.0
          : 0.7 + 0.3 * math.sin(t * 90 + spark.angle * 13);
      final alpha = now.opacity * twinkle;

      // Tail: pieces from the oldest (thin, faint) to the newest.
      var from = sparkAt(spark, math.max(spark.start, t - _tail));
      for (var i = 1; i <= _tailPieces && from != null; i++) {
        final to = sparkAt(
          spark,
          math.max(spark.start, t - _tail * (1 - i / _tailPieces)),
        );
        if (to == null) break;
        final k = i / _tailPieces;
        _stroke
          ..color = colour.withValues(alpha: alpha * k * 0.7)
          ..strokeWidth = 0.4 + 1.4 * k;
        canvas.drawLine(from.at, to.at, _stroke);
        from = to;
      }

      // Head: a soft halo, then a small bright core cooling to its colour.
      _glow.color = colour.withValues(alpha: alpha * 0.45);
      canvas.drawCircle(now.at, 3.5, _glow);
      _core.color = Color.lerp(
        hot,
        colour,
        math.min(1, now.life * 2.5),
      )!.withValues(alpha: alpha);
      canvas.drawCircle(now.at, 1.6, _core);
    }
  }

  @override
  bool shouldRepaint(FireworksPainter old) =>
      old.t != t || old.sparks != sparks;
}
