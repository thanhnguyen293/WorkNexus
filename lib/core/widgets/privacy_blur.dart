import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// Strong enough that words and faces can't be made out, light enough that
/// the layout (a bubble, an avatar) still reads.
const double _kBlurSigma = 6;

/// An area whose [PrivacyBlur]s all clear together while the pointer is over
/// it or keyboard focus is inside it — a chat-list row, so hovering anywhere
/// on it shows its name, avatar and preview at once. A [PrivacyBlur] outside
/// any region is its own region.
class PrivacyRevealRegion extends StatefulWidget {
  const PrivacyRevealRegion({super.key, required this.child});

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
      child: _RevealScope(revealed: _hovered || _focused, child: widget.child),
    ),
  );
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.revealed, required super.child});

  final bool revealed;

  @override
  bool updateShouldNotify(_RevealScope old) => old.revealed != revealed;
}

/// Blurs [child] while [blurred], unless its [PrivacyRevealRegion] is hovered
/// or focused. Only paints differently: the child, its state and what it
/// holds stay as they are, so turning the blur on or off loses nothing.
class PrivacyBlur extends StatelessWidget {
  const PrivacyBlur({super.key, required this.blurred, required this.child});

  final bool blurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layer = _BlurLayer(blurred: blurred, child: child);
    // The structure never depends on [blurred], so toggling it keeps the
    // child's state (a playing video, a text selection).
    return PrivacyRevealRegion.revealedOf(context) == null
        ? PrivacyRevealRegion(child: layer)
        : layer;
  }
}

class _BlurLayer extends StatelessWidget {
  const _BlurLayer({required this.blurred, required this.child});

  final bool blurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final revealed = PrivacyRevealRegion.revealedOf(context) ?? false;
    return ImageFiltered(
      enabled: blurred && !revealed,
      imageFilter: ImageFilter.blur(
        sigmaX: _kBlurSigma,
        sigmaY: _kBlurSigma,
        tileMode: TileMode.decal,
      ),
      child: child,
    );
  }
}
