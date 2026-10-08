import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

/// One destination in the app's left icon rail (board, chat, integrations):
/// an icon with a tooltip, highlighted when [selected], with an optional
/// [badge] (e.g. an unread count) on its top-right corner.
class AppRailButton extends StatelessWidget {
  const AppRailButton({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final badge = this.badge;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.xs),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: selected ? c.selectionFill : Colors.transparent,
              borderRadius: BorderRadius.circular(context.radii.lg),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(context.radii.lg),
                child: SizedBox.square(
                  dimension: s.xl6,
                  child: Icon(
                    selected ? selectedIcon : icon,
                    size: s.xl5,
                    color: selected ? c.accent : c.textSecondary,
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(top: -s.xs, right: -s.xs, child: badge),
          ],
        ),
      ),
    );
  }
}
