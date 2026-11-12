import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// The little pointer some messengers draw on a bubble.
enum BubbleTailKind {
  /// Telegram: a curl leaving the bottom corner of the last bubble in a run.
  curlBottom,

  /// WeChat: a small triangle near the top, pointing at the avatar.
  triangleTop,
}

/// The size of a bubble's tail.
abstract final class BubbleTail {
  /// Width the tail sticks out of the bubble (kept free beside it).
  static const double width = 7;

  /// Height of the tail along the bubble's edge.
  static const double height = 14;

  /// How far below the bubble's top a [BubbleTailKind.triangleTop] starts.
  static const double topInset = 8;
}

/// A bubble and its tail as one shape: one fill and one outline around both,
/// so a bordered bubble (TBChat's hairline) has no seam where the tail
/// meets it and the tail is outlined too. The tail sticks [BubbleTail.width]
/// out of the box on the avatar side ([tailOnLeft] for incoming messages);
/// the caller keeps that room free.
class TailedBubbleBorder extends ShapeBorder {
  const TailedBubbleBorder({
    required this.kind,
    required this.borderRadius,
    required this.tailOnLeft,
    this.side = BorderSide.none,
    this.tipOffset,
  });

  final BubbleTailKind kind;
  final BorderRadius borderRadius;
  final bool tailOnLeft;
  final BorderSide side;

  /// How far below the top a [BubbleTailKind.triangleTop] points — the
  /// avatar's centre, so it points at it. Defaults to just under the corner.
  final double? tipOffset;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => TailedBubbleBorder(
    kind: kind,
    borderRadius: borderRadius * t,
    tailOnLeft: tailOnLeft,
    side: side.scale(t),
    tipOffset: tipOffset == null ? null : tipOffset! * t,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  /// Drawn with the tail on the left; mirrored for a tail on the right.
  Path _path(Rect rect) {
    final r = tailOnLeft
        ? borderRadius
        : BorderRadius.only(
            topLeft: borderRadius.topRight,
            topRight: borderRadius.topLeft,
            bottomLeft: borderRadius.bottomRight,
            bottomRight: borderRadius.bottomLeft,
          );
    final l = rect.left;
    final t = rect.top;
    final rt = rect.right;
    final b = rect.bottom;
    const w = BubbleTail.width;
    const h = BubbleTail.height;
    final path = Path()
      ..moveTo(l + r.topLeft.x, t)
      ..lineTo(rt - r.topRight.x, t)
      ..arcToPoint(Offset(rt, t + r.topRight.y), radius: r.topRight)
      ..lineTo(rt, b - r.bottomRight.y)
      ..arcToPoint(Offset(rt - r.bottomRight.x, b), radius: r.bottomRight);
    switch (kind) {
      case BubbleTailKind.curlBottom:
        // The bottom corner on the tail side is square: the curl takes it.
        path
          ..lineTo(l - w, b)
          ..quadraticBezierTo(l, b - h * 0.2, l, b - h);
      case BubbleTailKind.triangleTop:
        final tip = tipOffset ?? BubbleTail.topInset + h * 0.5;
        // Clear of both corners' arcs, or the outline would double back
        // over one and kink.
        final lowest = b - t - r.bottomLeft.y - h * 0.7;
        final top = (tip - h * 0.35).clamp(
          r.topLeft.y,
          math.max(r.topLeft.y, lowest),
        );
        path
          ..lineTo(l + r.bottomLeft.x, b)
          ..arcToPoint(Offset(l, b - r.bottomLeft.y), radius: r.bottomLeft)
          ..lineTo(l, t + top + h * 0.7)
          ..lineTo(l - w, t + top + h * 0.35)
          ..lineTo(l, t + top);
    }
    path
      ..lineTo(l, t + r.topLeft.y)
      ..arcToPoint(Offset(l + r.topLeft.x, t), radius: r.topLeft)
      ..close();
    if (tailOnLeft) return path;
    // Mirror around the box's vertical centre line.
    // Column-major: x' = (left + right) − x.
    return path.transform(
      Float64List.fromList([
        -1, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        rect.left + rect.right, 0, 0, 1, //
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TailedBubbleBorder &&
      other.kind == kind &&
      other.borderRadius == borderRadius &&
      other.tailOnLeft == tailOnLeft &&
      other.side == side &&
      other.tipOffset == tipOffset;

  @override
  int get hashCode =>
      Object.hash(kind, borderRadius, tailOnLeft, side, tipOffset);
}
