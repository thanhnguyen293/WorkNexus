import 'package:flutter/animation.dart';

/// Shared **motion** tokens. Durations are matched to distance: hover and
/// press feedback is near-instant, a panel sliding in takes longer. Exits use
/// the shorter duration so dismissals feel snappy.
abstract final class AppMotion {
  /// Hover / focus / press feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// Small state changes: a chip toggling, a row expanding.
  static const Duration base = Duration(milliseconds: 180);

  /// Panels and overlays entering.
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}
