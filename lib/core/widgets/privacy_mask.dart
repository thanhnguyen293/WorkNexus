import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// What a hidden name or preview reads as: a fixed run of dots, so not even
/// the length of the real text shows.
const String kPrivacyMaskText = '••••••';

/// How much of a hidden message still shows: enough to see that a message is
/// there and how long it is, too little to read it at a glance.
const double _kFadedOpacity = 0.15;

/// An area whose [PrivacyMask]s and [PrivacyFade]s all show the real content
/// together while the pointer is over it or keyboard focus is inside it — a
/// chat-list row, so pointing anywhere on it shows its name, avatar and
/// preview at once. A mask or fade outside any region is its own region.
class PrivacyRevealRegion extends StatefulWidget {
  const PrivacyRevealRegion({
    super.key,
    this.revealOnFocus = true,
    required this.child,
  });

  /// Off for an area holding a text field: the field keeps focus while the
  /// user types, which would leave everything around it shown.
  final bool revealOnFocus;
  final Widget child;

  /// Whether the region around [context] is being hovered or focused; null
  /// when there is no region around it.
  static bool? revealedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RevealScope>()?.revealed;

  @override
  State<PrivacyRevealRegion> createState() => _PrivacyRevealRegionState();
}

class _PrivacyRevealRegionState extends State<PrivacyRevealRegion> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      // Only listens: focus moving onto anything inside reveals the region.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (on) => setState(() => _focused = on),
      child: _RevealScope(
        revealed: _hovered || (_focused && widget.revealOnFocus),
        child: widget.child,
      ),
    ),
  );
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.revealed, required super.child});

  final bool revealed;

  @override
  bool updateShouldNotify(_RevealScope old) => old.revealed != revealed;
}

/// Wraps [child] in a [PrivacyRevealRegion] unless one is already around it.
/// Depends only on the tree above, never on whether anything is hidden, so
/// turning the privacy mode on or off keeps [child]'s state.
Widget _inRegion(BuildContext context, Widget child) =>
    PrivacyRevealRegion.revealedOf(context) == null
    ? PrivacyRevealRegion(child: child)
    : child;

/// Shows [mask] in place of [child] while [masked], unless its
/// [PrivacyRevealRegion] is hovered or focused. For content without state of
/// its own — a name, an avatar, a preview line.
class PrivacyMask extends StatelessWidget {
  const PrivacyMask({
    super.key,
    required this.masked,
    required this.mask,
    required this.child,
  });

  final bool masked;
  final Widget mask;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _inRegion(context, _MaskLayer(masked: masked, mask: mask, child: child));
}

class _MaskLayer extends StatelessWidget {
  const _MaskLayer({
    required this.masked,
    required this.mask,
    required this.child,
  });

  final bool masked;
  final Widget mask;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hidden =
        masked && !(PrivacyRevealRegion.revealedOf(context) ?? false);
    // Dots and text crossfade, both pinned to the start so the text does not
    // slide while the two widths differ. They get the constraints the mask
    // gets, as they would without it: loosened, a centered title shrinks to
    // its text and sits at the start.
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(hidden), child: hidden ? mask : child),
    );
  }
}

/// Fades [child] almost out while [faded], unless its [PrivacyRevealRegion]
/// is hovered or focused. For content on a solid background (a bubble's
/// text): over the wallpaper it would let the wallpaper show through. Only
/// paints differently: the child, its state (a text selection) and its
/// layout stay as they are.
class PrivacyFade extends StatelessWidget {
  const PrivacyFade({super.key, required this.faded, required this.child});

  final bool faded;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _inRegion(context, _FadeLayer(faded: faded, child: child));
}

class _FadeLayer extends StatelessWidget {
  const _FadeLayer({required this.faded, required this.child});

  final bool faded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final on = faded && !(PrivacyRevealRegion.revealedOf(context) ?? false);
    // At rest (fully shown) it adds no layer: an opacity of 1 paints the
    // child as it is.
    return AnimatedOpacity(
      opacity: on ? _kFadedOpacity : 1,
      duration: AppMotion.of(context, AppMotion.base),
      curve: AppMotion.enter,
      child: child,
    );
  }
}

/// Lays a solid [color] box over [child] while [covered], unless its
/// [PrivacyRevealRegion] is hovered or focused — for a picture, which a fade
/// would only dim. [child] stays built under it, so a video keeps playing
/// and a picture need not load again.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({
    super.key,
    required this.covered,
    required this.color,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  });

  final bool covered;
  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => _inRegion(
    context,
    _CoverLayer(
      covered: covered,
      color: color,
      borderRadius: borderRadius,
      child: child,
    ),
  );
}

class _CoverLayer extends StatelessWidget {
  const _CoverLayer({
    required this.covered,
    required this.color,
    required this.borderRadius,
    required this.child,
  });

  final bool covered;
  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final on = covered && !(PrivacyRevealRegion.revealedOf(context) ?? false);
    return Stack(
      children: [
        child,
        // Last, so it never moves [child] and loses its state. Always there,
        // to ease in and out; fully clear it paints nothing.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: AppMotion.of(context, AppMotion.base),
              curve: AppMotion.enter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: borderRadius,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
