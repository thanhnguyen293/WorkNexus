import 'package:flutter/widgets.dart';

/// The little pointer some messengers draw on a bubble.
enum BubbleTailKind {
  /// Telegram: a curl leaving the bottom corner of the last bubble in a run.
  curlBottom,

  /// WeChat: a small triangle near the top, pointing at the avatar.
  triangleTop,
}

/// Paints a [BubbleTailKind] tail in [color]. Laid out beside the bubble on
/// the avatar side; [pointsLeft] for incoming messages.
class BubbleTail extends StatelessWidget {
  const BubbleTail({
    super.key,
    required this.kind,
    required this.color,
    required this.pointsLeft,
  });

  /// Width the tail sticks out of the bubble.
  static const double width = 7;

  final BubbleTailKind kind;
  final Color color;
  final bool pointsLeft;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(width, 14),
    painter: _TailPainter(kind, color, pointsLeft),
  );
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.kind, this.color, this.pointsLeft);

  final BubbleTailKind kind;
  final Color color;
  final bool pointsLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Drawn pointing left; mirrored for outgoing bubbles.
    final path = switch (kind) {
      BubbleTailKind.curlBottom =>
        Path()
          ..moveTo(w, 0)
          ..quadraticBezierTo(w, h * 0.8, 0, h)
          ..lineTo(w, h)
          ..close(),
      BubbleTailKind.triangleTop =>
        Path()
          ..moveTo(w, h * 0.15)
          ..lineTo(0, h * 0.5)
          ..lineTo(w, h * 0.85)
          ..close(),
    };
    if (!pointsLeft) {
      canvas
        ..translate(w, 0)
        ..scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.kind != kind || old.color != color || old.pointsLeft != pointsLeft;
}
