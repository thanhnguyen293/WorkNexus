import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A wrap of label/tag chips. When a label name has a provider color in
/// [colors] (`#RRGGBB` background) the chip is filled to match the provider's
/// configured palette, using [textColors] for the text (falling back to a
/// readable contrast); otherwise it renders as a neutral outlined chip.
class LabelChips extends StatelessWidget {
  const LabelChips({
    super.key,
    required this.labels,
    this.colors = const {},
    this.textColors = const {},
  });

  final List<String> labels;
  final Map<String, String> colors;
  final Map<String, String> textColors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.spacing.xs,
      runSpacing: context.spacing.xs,
      children: [for (final label in labels) _chip(context, label)],
    );
  }

  Widget _chip(BuildContext context, String label) {
    final c = context.colors;
    final bg = _parseHex(colors[label]);
    if (bg == null) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.xs),
          border: context.borders.showOutline
              ? Border.all(color: c.border)
              : null,
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: context.typography.monoXs.copyWith(color: c.textSecondary),
        ),
      );
    }
    // Prefer the provider's own text color; otherwise pick a readable ink token
    // based on how light the fill is.
    final fg =
        _parseHex(textColors[label]) ??
        (bg.computeLuminance() > 0.5 ? c.onColorInk : c.onAccent);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: context.typography.monoXs.copyWith(color: fg),
      ),
    );
  }

  /// Parses a `#RRGGBB` / `#RGB` (or unprefixed) hex into an opaque color; null
  /// when malformed. Data-driven (provider palette), not a design token.
  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) h = h.split('').map((ch) => '$ch$ch').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
