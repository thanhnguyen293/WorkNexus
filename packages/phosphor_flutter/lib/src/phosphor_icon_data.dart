library phosphor_flutter;

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/src/phosphor_duotone_secondaries.dart';

// WorkNexus patch (see PATCH.md): Flutter 3.44 made IconData a final class, so
// the original `PhosphorIconData extends IconData` no longer compiles. Every
// Phosphor glyph is now a plain IconData; the old names remain as aliases.

/// A Phosphor icon glyph.
typedef PhosphorIconData = IconData;

/// A single-layer Phosphor icon glyph.
typedef PhosphorFlatIconData = IconData;

/// A two-layer duotone glyph: this is the primary layer, drawn by
/// [PhosphorIcon] over the translucent [secondary] layer.
extension type const PhosphorDuotoneIconData(IconData primary)
    implements IconData {
  /// Extension types are erased at runtime, so `is PhosphorDuotoneIconData`
  /// cannot tell a duotone glyph apart; this checks the glyph itself.
  static bool isDuotone(IconData icon) =>
      icon.fontFamily == 'PhosphorDuotone' &&
      icon.fontPackage == 'phosphor_flutter' &&
      phosphorDuotoneSecondaries.containsKey(icon.codePoint);

  /// The translucent background layer of this glyph.
  IconData get secondary => phosphorDuotoneSecondaries[codePoint]!;
}
