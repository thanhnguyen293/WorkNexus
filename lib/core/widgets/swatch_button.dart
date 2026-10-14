import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import 'hover_surface.dart';

/// One round colour swatch with a ring when [selected]; with no [color] it is
/// the "pick your own" button (a plus).
class SwatchButton extends StatelessWidget {
  const SwatchButton({
    super.key,
    required this.size,
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final double size;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = this.color;
    // A 2px ring, then a 1.5px gap, around the dot.
    const ring = 2.0;
    const ringGap = 1.5;
    final swatch = HoverSurface(
      onTap: onTap,
      shape: BoxShape.circle,
      width: size,
      height: size,
      padding: const EdgeInsets.all(ringGap),
      // The ring answers hover, not a tint: a tint would shift the colour.
      tintOnHover: false,
      border: Border.all(
        color: selected ? c.textPrimary : Colors.transparent,
        width: ring,
      ),
      hoverBorder: Border.all(
        color: selected ? c.textPrimary : c.borderStrong,
        width: ring,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? c.surfaceSubtle,
          shape: BoxShape.circle,
          border: Border.all(
            color: color == null ? c.borderStrong : c.mixT(c.scrim, 0.12),
          ),
        ),
        child: color == null
            ? Icon(
                LucideIcons.plus300,
                size: size * 0.45,
                color: c.textSecondary,
              )
            : const SizedBox.expand(),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null ? swatch : Tooltip(message: tooltip, child: swatch);
  }
}
