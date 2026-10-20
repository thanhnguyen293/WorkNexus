import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';

/// The bar over a GitLab or GitHub board, one row of controls at one height,
/// laid out like the ZenTao boards' toolbar: the quick [filters] on the left;
/// [refresh] and the view [modes] on the right.
class BoardToolbar extends StatelessWidget {
  const BoardToolbar({
    super.key,
    this.filters = const [],
    required this.refresh,
    required this.modes,
    required this.viewMode,
    required this.onViewMode,
  });

  /// Left out when empty.
  final List<AppSegmentedTab> filters;
  final Widget refresh;
  final List<ToolViewMode> modes;
  final ViewModeId viewMode;
  final ValueChanged<ViewModeId> onViewMode;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
        child: Row(
          spacing: s.sm,
          children: [
            if (filters.isNotEmpty) AppSegmentedTabs(tabs: filters),
            const Spacer(),
            refresh,
            AppSegmentedTabs(
              tabs: [
                for (final m in modes)
                  AppSegmentedTab(
                    label: m.label(l),
                    icon: m.icon,
                    active: m.id == viewMode,
                    onTap: () => onViewMode(m.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
