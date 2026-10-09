import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Builds a subtree for the current pointer-hover state. [child] is the
/// hover-independent subtree handed to [HoverRegion.child], if any.
typedef HoverWidgetBuilder =
    Widget Function(BuildContext context, bool hovered, Widget? child);

/// Tracks whether the mouse is over its subtree and rebuilds [builder] when
/// that changes.
///
/// It paints nothing itself: the builder decides what "hovered" looks like (a
/// stronger text colour, a revealed action, …). For the common case of a
/// tappable block that tints its own fill, use [HoverSurface].
class HoverRegion extends StatefulWidget {
  const HoverRegion({
    super.key,
    required this.builder,
    this.child,
    this.cursor = MouseCursor.defer,
    this.enabled = true,
    this.hitTestBehavior,
  });

  final HoverWidgetBuilder builder;

  /// Passed to [builder] unchanged, so a subtree that doesn't depend on the
  /// hover state is built once rather than on every enter/exit.
  final Widget? child;

  /// Cursor shown while hovering (and [enabled]).
  final MouseCursor cursor;

  /// When false the builder always sees `hovered == false` and the cursor is
  /// the platform default — for disabled controls.
  final bool enabled;

  final HitTestBehavior? hitTestBehavior;

  @override
  State<HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return MouseRegion(
      cursor: enabled ? widget.cursor : MouseCursor.defer,
      hitTestBehavior: widget.hitTestBehavior,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(context, enabled && _hovered, widget.child),
    );
  }
}

/// A tappable block that tints its fill with `colors.hoverFill` while the
/// pointer is over it: the app's one hover treatment for surfaces that draw
/// their own decoration (cards, chips, tabs, toolbar buttons).
///
/// Use it where an [InkWell] won't do — the ink highlight is painted on the
/// nearest [Material], so an opaque [Container] above it hides the hover.
/// [HoverSurface] draws the fill and the tint in one [AnimatedContainer], so it
/// needs no Material ancestor and no care about paint order.
///
/// Geometry mirrors [Container]; the resting look is [color] / [border] /
/// [borderRadius] / [shape] / [boxShadow]. While hovered the fill is overlaid
/// with [hoverColor] (default `colors.hoverFill`) and [border] swaps to
/// [hoverBorder] when one is given. A colour swatch, where a tint would shift
/// the very colour on show, sets [tintOnHover] false and answers with the
/// border alone. Hover feedback and the hand cursor are off while no tap
/// handler is set, unless [enabled] says otherwise — e.g. a block whose tap
/// targets are its children.
class HoverSurface extends StatelessWidget {
  const HoverSurface({
    super.key,
    this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.enabled,
    this.color,
    this.hoverColor,
    this.tintOnHover = true,
    this.border,
    this.hoverBorder,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.boxShadow,
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.constraints,
    this.clipBehavior = Clip.none,
    this.behavior,
    this.cursor = SystemMouseCursors.click,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget? child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  /// Overrides the "has a handler" default for whether hover feedback shows.
  final bool? enabled;

  /// Resting fill; null draws none.
  final Color? color;

  /// Overlaid on [color] while hovered. Defaults to `colors.hoverFill`.
  final Color? hoverColor;

  /// False keeps the fill as it is on hover; only [hoverBorder] answers.
  final bool tintOnHover;

  final BoxBorder? border;

  /// Replaces [border] while hovered (e.g. the stronger line).
  final BoxBorder? hoverBorder;

  final BorderRadius? borderRadius;
  final BoxShape shape;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final Clip clipBehavior;

  /// How the tap area hit-tests; see [GestureDetector.behavior].
  final HitTestBehavior? behavior;
  final MouseCursor cursor;

  /// Length of the rest ↔ hovered transition.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final interactive =
        onTap != null || onLongPress != null || onSecondaryTapUp != null;
    return HoverRegion(
      enabled: enabled ?? interactive,
      cursor: cursor,
      child: child,
      builder: (context, hovered, child) {
        final base = color ?? Colors.transparent;
        final tint = tintOnHover
            ? hoverColor ?? context.colors.hoverFill
            : null;
        return GestureDetector(
          behavior: behavior,
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTapUp: onSecondaryTapUp,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: width,
            height: height,
            alignment: alignment,
            constraints: constraints,
            padding: padding,
            clipBehavior: clipBehavior,
            decoration: BoxDecoration(
              color: hovered && tint != null
                  ? Color.alphaBlend(tint, base)
                  : base,
              border: hovered ? (hoverBorder ?? border) : border,
              // A circle can't carry a radius; the shape rounds it instead.
              borderRadius: shape == BoxShape.circle ? null : borderRadius,
              shape: shape,
              boxShadow: boxShadow,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
