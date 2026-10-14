import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Width of the invisible grab strip.
const double kResizeHandleWidth = 8.0;

/// Width of the accent line shown while the grab strip is hovered/dragged.
const double _kLineWidth = 2.0;

/// A thin grab strip that resizes whatever sits on its left: a resize cursor
/// on hover, an accent line along its right edge while hovered or dragging,
/// horizontal drag deltas forwarded to [onDelta]. Fills the height it is given.
class ResizeHandle extends StatefulWidget {
  const ResizeHandle({
    super.key,
    required this.onDelta,
    required this.onEnd,
    this.onReset,
  });

  final ValueChanged<double> onDelta;

  /// The drag let go — the moment to persist the new size.
  final VoidCallback onEnd;

  /// A double-click, to restore the default size.
  final VoidCallback? onReset;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd();
        },
        child: SizedBox(
          width: kResizeHandleWidth,
          height: double.infinity,
          // The accent line sits on the resized edge, over its hairline.
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: _kLineWidth,
              height: double.infinity,
              child: active ? ColoredBox(color: c.accent) : null,
            ),
          ),
        ),
      ),
    );
  }
}
