import 'package:flutter/widgets.dart';

/// What a hidden name or preview reads as: a fixed run of dots, so not even
/// the length of the real text shows.
const String kPrivacyMaskText = '••••••';

/// How much of a hidden message still shows: enough to see that a message is
/// there and how long it is, too little to read it at a glance.
const double _kFadedOpacity = 0.12;

/// An area whose [PrivacyMask]s and [PrivacyFade]s all show the real content
/// together while the pointer is over it or keyboard focus is inside it — a
/// chat-list row, so pointing anywhere on it shows its name, avatar and
/// preview at once. A mask or fade outside any region is its own region.
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
  Widget build(BuildContext context) =>
      masked && !(PrivacyRevealRegion.revealedOf(context) ?? false)
      ? mask
      : child;
}

/// Fades [child] almost out while [faded], unless its [PrivacyRevealRegion]
/// is hovered or focused. Only paints differently: the child, its state (a
/// playing video, a text selection) and its layout stay as they are.
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
    final revealed = PrivacyRevealRegion.revealedOf(context) ?? false;
    return Opacity(
      opacity: faded && !revealed ? _kFadedOpacity : 1,
      child: child,
    );
  }
}
