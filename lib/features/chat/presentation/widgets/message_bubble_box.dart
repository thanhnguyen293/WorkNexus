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
        final box = AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: color,
            border: border == null ? null : Border.all(color: border),
            borderRadius: borderRadius,
          ),
          child: content,
        );
        return switch (tail) {
          final kind? => BubbleWithTail(
            kind: kind,
            color: color,
            mine: mine,
            child: box,
          ),
          null => box,
        };
      },
      child: Padding(padding: padding, child: child),
    );
  }
}
