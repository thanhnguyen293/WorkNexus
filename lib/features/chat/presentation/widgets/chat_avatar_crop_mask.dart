import 'package:flutter/material.dart';

/// How much the part of the picture the avatar drops is dimmed.
const _kScrimAlpha = 0.55;

/// How strongly the square frame's own edge shows (the circle is the avatar).
const _kEdgeAlpha = 0.6;

/// Dims [picture] outside the round avatar inscribed in [frame], and draws
/// the frame's edge, the circle and a dot on each corner grip.
class ChatAvatarCropMask extends CustomPainter {
  const ChatAvatarCropMask({
    required this.picture,
    required this.frame,
    required this.scrim,
    required this.ink,
    required this.ringWidth,
    required this.dotRadius,
  });

  final Rect picture;
  final Rect frame;
  final Color scrim;
  final Color ink;
  final double ringWidth;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth / 2
      ..color = ink.withValues(alpha: _kEdgeAlpha);
    canvas
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(picture)
          ..addOval(frame),
        Paint()..color = scrim.withValues(alpha: _kScrimAlpha),
      )
      ..drawRect(frame, stroke)
      ..drawOval(
        frame.deflate(ringWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..color = ink,
      );
    final dot = Paint()..color = ink;
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      canvas.drawCircle(corner, dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(ChatAvatarCropMask old) =>
      old.picture != picture ||
      old.frame != frame ||
      old.scrim != scrim ||
      old.ink != ink ||
      old.ringWidth != ringWidth ||
      old.dotRadius != dotRadius;
}
