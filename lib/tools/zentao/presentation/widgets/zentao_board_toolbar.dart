import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/widgets/filters_button.dart';
import 'zentao_board_refresh_button.dart';
import 'zentao_status_filter_option.dart';

/// The bar under a ZenTao board's header, one row of the toolbar's controls
/// at one height: what to show ([scopes]: all, assigned to me…) and the
/// filters on the left; refresh and the view modes on the right.
class ZenTaoBoardToolbar extends ConsumerWidget {
  const ZenTaoBoardToolbar({
    super.key,
    required this.bugs,
    required this.scopes,
    required this.modes,
    required this.viewMode,
  });

  /// The bug board, else the task board.
  final bool bugs;
  final List<AppSegmentedTab> scopes;
  final List<ToolViewMode> modes;
  final ViewModeId viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            AppSegmentedTabs(tabs: scopes),
            FiltersButton(
              statusOption: zentaoStatusFilterOption(bugBoard: bugs),
            ),
            const Spacer(),
            ZenTaoBoardRefreshButton(bugs: bugs),
            AppSegmentedTabs(
              tabs: [
                for (final m in modes)
                  AppSegmentedTab(
                    label: m.label(l),
                    icon: m.icon,
                    active: m.id == viewMode,
                    onTap: () =>
                        ref.read(appNavProvider.notifier).setViewMode(m.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
