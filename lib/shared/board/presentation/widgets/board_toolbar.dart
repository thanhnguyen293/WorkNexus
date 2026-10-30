import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_segmented_tabs_menu.dart';
import '../../../../l10n/app_localizations.dart';
import 'board_toolbar_layout.dart';

/// The bar over a board, one row of controls at one height: the quick
/// [filters] (and the board's [filtersButton], if it has one) on the left;
/// [refresh] and the view [modes] on the right. A narrow window folds it
/// (see [BoardToolbarLayout]) rather than letting it overflow.
class BoardToolbar extends StatelessWidget {
  const BoardToolbar({
    super.key,
    this.filters = const [],
    this.filtersButton,
    required this.refresh,
    required this.modes,
    required this.viewMode,
    required this.onViewMode,
  });

  /// Left out when empty.
  final List<AppSegmentedTab> filters;

  /// The advanced filters, after the quick ones.
  final Widget? filtersButton;
  final Widget refresh;
  final List<ToolViewMode> modes;
  final ViewModeId viewMode;
  final ValueChanged<ViewModeId> onViewMode;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final modeTabs = [
      for (final m in modes)
        AppSegmentedTab(
          label: m.label(l),
          icon: m.icon,
          active: m.id == viewMode,
          onTap: () => onViewMode(m.id),
        ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
        child: BoardToolbarLayout(
          gap: s.sm,
          scopes: filters.isEmpty ? null : AppSegmentedTabs(tabs: filters),
          scopesMenu: filters.isEmpty
              ? null
              : AppSegmentedTabsMenu(tabs: filters),
          filters: filtersButton,
          refresh: refresh,
          modes: AppSegmentedTabs(tabs: modeTabs),
          modesCompact: AppSegmentedTabs(tabs: modeTabs, iconOnly: true),
        ),
      ),
    );
  }
}
