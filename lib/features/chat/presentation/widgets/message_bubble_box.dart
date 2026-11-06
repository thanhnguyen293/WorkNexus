import 'package:flutter/material.dart';

import '../../../../core/widgets/hover_surface.dart';
import 'bubble_tail.dart';

/// A message bubble's own shape: its fill, border, corners and tail. Under
/// the pointer the fill (and its tail) takes [hoverFill] over it, so only the
/// bubble lights up, never the whole row.
class MessageBubbleBox extends StatelessWidget {
  const MessageBubbleBox({
    super.key,
    required this.fill,
    required this.hoverFill,
    required this.borderRadius,
    required this.padding,
    required this.mine,
    required this.child,
    this.borderColor,
    this.tail,
  });

  final Color fill;

  /// Tint laid over [fill] on hover (the bubble ink's `hoverFill`, so it
  /// reads on light and dark bubbles alike).
  final Color hoverFill;
  final Color? borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool mine;

  /// Drawn on the avatar side when set; the caller keeps the room for it.
  final BubbleTailKind? tail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return HoverRegion(
      builder: (context, hovered, content) {
        final color = hovered ? Color.alphaBlend(hoverFill, fill) : fill;
        final side = border == null
            ? BorderSide.none
            : BorderSide(color: border);
        final kind = tail;
        if (kind == null) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: color,
              border: border == null ? null : Border.fromBorderSide(side),
              borderRadius: borderRadius,
            ),
            child: content,
          );
        }
        // Bubble and tail as one shape, so the outline runs around both.
        return Padding(
          // Room for the tail, which is drawn outside the box.
          padding: EdgeInsets.only(
            left: mine ? 0 : BubbleTail.width,
            right: mine ? BubbleTail.width : 0,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: ShapeDecoration(
              color: color,
              shape: TailedBubbleBorder(
                kind: kind,
                borderRadius: borderRadius,
                tailOnLeft: !mine,
                side: side,
              ),
            ),
            child: content,
          ),
        );
      },
      child: Padding(padding: padding, child: child),
    );
  }
}
