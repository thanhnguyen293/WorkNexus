import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../shared/board/presentation/widgets/board_toolbar.dart';
import '../../../../shared/board/presentation/widgets/filters_button.dart';
import '../providers/zentao_facet_catalog_provider.dart';
import 'zentao_board_refresh_button.dart';
import 'zentao_status_filter_option.dart';

/// The bar under a ZenTao board's header: the shared [BoardToolbar], with
/// what to show ([scopes]: all, related to me…) and the Filters button.
class ZenTaoBoardToolbar extends ConsumerWidget {
  const ZenTaoBoardToolbar({
    super.key,
    required this.bugs,
    required this.scopes,
    required this.modes,
    required this.viewMode,
    this.filtering = true,
    this.keepViewOnPick = false,
    this.searchScope,
  });

  /// The bug board, else the task board.
  final bool bugs;

  /// What to show, the All view first.
  final List<AppSegmentedTab> scopes;
  final List<ToolViewMode> modes;
  final ViewModeId viewMode;

  /// Off on a view that is a filter of its own (Related to me): no Filters
  /// button there.
  final bool filtering;

  /// Picking a filter keeps the view on screen; otherwise it moves to the
  /// All view, so the filter shows over every ticket.
  final bool keepViewOnPick;

  /// The picked product / execution, named in the search's placeholder.
  final String? searchScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BoardToolbar(
    filters: scopes,
    searchScope: searchScope,
    filtersButton: filtering
        ? FiltersButton(
            statusOption: zentaoStatusFilterOption(bugBoard: bugs),
            catalog: ref.watch(zentaoFacetCatalogProvider(bugs)),
            // Picking a filter shows it over every ticket: the All view.
            onPick: keepViewOnPick || scopes.first.active
                ? null
                : scopes.first.onTap,
          )
        : null,
    refresh: ZenTaoBoardRefreshButton(bugs: bugs),
    modes: modes,
    viewMode: viewMode,
    onViewMode: (id) => ref.read(appNavProvider.notifier).setViewMode(id),
  );
}
