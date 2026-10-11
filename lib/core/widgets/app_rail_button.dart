import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

/// One entry in the app's left icon rail: an icon with a tooltip and an
/// optional [badge] (e.g. an unread count) on its top-right corner.
///
/// A destination (dashboard, board, chat) shows [selected] with a tinted fill,
/// the accent icon and an accent bar on the rail's edge. [primary] is for the
/// rail's one action ("+ new"): an accent-filled button that never reads as a
/// place.
class AppRailButton extends StatelessWidget {
  const AppRailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.primary = false,
  });

  /// The rail's side gutter: the button is centred in the rail, so the edge
  /// bar sits this far to its left.
  static double gutterOf(BuildContext context) => context.spacing.md;

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final badge = this.badge;
    final radius = BorderRadius.circular(context.radii.lg);
    final Color fill = primary
        ? c.accent
        : selected
        ? c.selectionFill
        : Colors.transparent;
    final Color ink = primary
        ? c.onAccent
        : selected
        ? c.accent
        : c.textSecondary;
    return Semantics(
      button: true,
      selected: primary ? null : selected,
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.xxs),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Material(
                color: fill,
                borderRadius: radius,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: onTap,
                  borderRadius: radius,
                  // On the accent fill the theme's ink tint barely shows.
                  hoverColor: primary
                      ? c.onAccent.withValues(alpha: 0.14)
                      : null,
                  child: SizedBox.square(
                    dimension: s.xl6,
                    child: Icon(icon, size: context.sizes.iconLg, color: ink),
                  ),
                ),
              ),
              if (selected && !primary)
                Positioned(left: -gutterOf(context), child: const _EdgeBar()),
              if (badge != null)
                Positioned(top: -s.xs, right: -s.xs, child: badge),
            ],
          ),
        ),
      ),
    );
  }
}

/// The accent bar marking the current destination on the rail's left edge.
class _EdgeBar extends StatelessWidget {
  const _EdgeBar();

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(context.radii.dot);
    return Container(
      width: context.borders.accent,
      height: context.sizes.iconLg,
      decoration: BoxDecoration(
        color: context.colors.accent,
        borderRadius: BorderRadius.horizontal(right: r),
      ),
    );
  }
}

/// A short hairline between the rail's groups (the action, the destinations,
/// the utilities).
class AppRailDivider extends StatelessWidget {
  const AppRailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: SizedBox(
        width: context.spacing.xl5,
        child: Divider(color: context.colors.border),
      ),
    );
  }
}
