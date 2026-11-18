import 'package:flutter/widgets.dart';

/// What a hidden name or preview reads as: a fixed run of dots, so not even
/// the length of the real text shows.
const String kPrivacyMaskText = '••••••';

/// How much of a hidden message's own colour is kept, the rest being the
/// fade colour: enough to see that a message is there and how long it is,
/// too little to read it at a glance.
const double _kFadedKeep = 0.12;

/// Leaves every colour as it is.
const List<double> _kIdentity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

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
  Widget build(BuildContext context) =>
      masked && !(PrivacyRevealRegion.revealedOf(context) ?? false)
      ? mask
      : child;
}

/// Washes [child] out towards [color] while [faded], unless its
/// [PrivacyRevealRegion] is hovered or focused. Opacity stays as it is, so a
/// bubble stays solid over the wallpaper while its text and pictures all but
/// vanish into it; what is transparent (the wallpaper between bubbles) stays
/// untouched. Only paints differently: the child, its state (a playing video,
/// a text selection) and its layout stay as they are. One fade over a whole
/// list costs a single layer.
class PrivacyFade extends StatelessWidget {
  const PrivacyFade({
    super.key,
    required this.faded,
    required this.color,
    required this.child,
  });

  final bool faded;

  /// What the content fades into — the surface it sits on.
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _inRegion(context, _FadeLayer(faded: faded, color: color, child: child));
}

class _FadeLayer extends StatelessWidget {
  const _FadeLayer({
    required this.faded,
    required this.color,
    required this.child,
  });

  final bool faded;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final on = faded && !(PrivacyRevealRegion.revealedOf(context) ?? false);
    // Always filtered, the identity when shown: swapping the widget out
    // would rebuild [child] and lose its state.
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(on ? _washTowards(color) : _kIdentity),
      child: child,
    );
  }
}

/// Keeps [_kFadedKeep] of each colour and fills the rest with [color],
/// leaving alpha alone.
List<double> _washTowards(Color color) {
  const k = _kFadedKeep;
  double fill(double channel) => (1 - k) * channel * 255;
  return [
    k, 0, 0, 0, fill(color.r), //
    0, k, 0, 0, fill(color.g), //
    0, 0, k, 0, fill(color.b), //
    0, 0, 0, 1, 0, //
  ];
}
