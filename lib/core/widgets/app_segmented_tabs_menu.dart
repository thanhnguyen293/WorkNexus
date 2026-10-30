import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_context_menu.dart';
import 'app_segmented_tabs.dart';
import 'hover_surface.dart';

/// [AppSegmentedTabs] folded into one control for a toolbar too narrow for
/// the row: the active tab's label with a caret, the tabs in a menu.
class AppSegmentedTabsMenu extends StatefulWidget {
  const AppSegmentedTabsMenu({super.key, required this.tabs});

  final List<AppSegmentedTab> tabs;

  @override
  State<AppSegmentedTabsMenu> createState() => _AppSegmentedTabsMenuState();
}

class _AppSegmentedTabsMenuState extends State<AppSegmentedTabsMenu> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final tabs = widget.tabs;
    final active = tabs.firstWhere((t) => t.active, orElse: () => tabs.first);
    return MenuAnchor(
      controller: _menu,
      style: appMenuAnchorStyle,
      alignmentOffset: Offset(0, s.xs),
      menuChildren: [
        AppMenuPanel(
          entries: [
            for (final tab in tabs)
              AppMenuEntry(
                icon: tab.icon,
                label: tab.label,
                checked: tab.active,
              ),
          ],
          onSelected: (i) {
            _menu.close();
            tabs[i].onTap();
          },
        ),
      ],
      builder: (context, menu, _) => Container(
        height: context.sizes.controlMd,
        padding: EdgeInsets.all(s.xxs),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: context.cardBorder,
        ),
        child: HoverSurface(
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          selected: true,
          padding: EdgeInsets.symmetric(horizontal: s.lg),
          alignment: Alignment.center,
          color: c.surface,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: context.cardBorder,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                active.label,
                maxLines: 1,
                style: context.typography.bodySm.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: s.sm),
              Icon(
                LucideIcons.chevronDown300,
                size: context.sizes.iconSm,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
