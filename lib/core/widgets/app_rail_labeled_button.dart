import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'hover_surface.dart';

/// A place on the left rail with its name under the glyph: the workspace, an
/// account, a mini app.
///
/// [leading] is tinted by the rail's ink through [IconTheme] and
/// [DefaultTextStyle] (an icon, a letter) unless it paints its own colours (a
/// provider logo, a site's icon). [selected] shows a tinted fill, accent ink
/// and an accent bar on the rail's edge; [badge] sits on the glyph's
/// top-right corner.
class AppRailLabeledButton extends StatelessWidget {
  const AppRailLabeledButton({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.badge,
  });

  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Hover text; [label] when null.
  final String? tooltip;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final ink = selected ? c.accent : c.textSecondary;
    final badge = this.badge;

    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: tooltip ?? label,
        preferBelow: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.xxs),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              HoverSurface(
                onTap: onTap,
                selected: selected,
                borderRadius: BorderRadius.circular(r.md),
                color: selected ? c.selectionFill : Colors.transparent,
                padding: EdgeInsets.all(s.xs),
                child: SizedBox(
                  width: context.sizes.railWidth - s.xl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          SizedBox.square(
                            dimension: context.sizes.railButton,
                            child: Center(
                              child: IconTheme(
                                data: IconThemeData(
                                  color: ink,
                                  size: context.sizes.iconLg,
                                ),
                                child: DefaultTextStyle.merge(
                                  style: context.typography.body.copyWith(
                                    color: ink,
                                  ),
                                  child: leading,
                                ),
                              ),
                            ),
                          ),
                          if (badge != null)
                            Positioned(top: -s.xs, right: -s.sm, child: badge),
                        ],
                      ),
                      SizedBox(height: s.xxs),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.typography.captionSm.copyWith(
                          color: ink,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: context.borders.accent,
                    height: context.sizes.iconXl,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(r.xs),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
