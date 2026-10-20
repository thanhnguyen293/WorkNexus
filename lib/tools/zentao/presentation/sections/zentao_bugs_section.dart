import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/domain/value_objects/saved_view.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../providers/zentao_board_providers.dart';
import '../util/keep_bug_board_product.dart';
import '../widgets/zentao_board_toolbar.dart';
import '../widgets/zentao_bug_board_view.dart';
import '../widgets/zentao_bug_section_header.dart';
import '../widgets/zentao_bug_table_view.dart';

/// The L5 Viewport section for ZenTao Bugs, formatted after slide 02 (specs.md §5.1, §5.2).
/// Displays Viewport Header (Scope dot, name, count, + New bug), View Mode Tabs,
/// Quick Filter Chips (All, Assigned to me), and Filter Button.
class ZentaoBugsSection extends ConsumerWidget {
  const ZentaoBugsSection({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  static List<ToolViewMode> get modes => [
    ToolViewMode(
      id: const ViewModeId('board'),
      label: (l) => l.viewBoard,
      icon: LucideIcons.kanban300,
    ),
    ToolViewMode(
      id: const ViewModeId('list'),
      label: (l) => l.viewList,
      icon: LucideIcons.list300,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('board');

    final filter = ref.watch(filterStateProvider);
    final isRelated = filter.savedView == SavedView.related;
    // The chip lives in the per-board filter (a first visit defaults to
    // "related to me"); the bug views that load follow it, or it would be
    // shown over the unclosed views' first pages only.
    final tab = ref.watch(zentaoBugTabProvider);
    final wantTab = isRelated
        ? ZenTaoBugBrowseType.relatedToMe
        : (tab == ZenTaoBugBrowseType.relatedToMe
              ? ZenTaoBugBrowseType.unclosed
              : tab);
    // Only while on screen: the viewport keeps a few sections alive, and an
    // off-screen one must not restart the views another board is loading.
    if (wantTab != tab && TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(zentaoBugTabProvider.notifier).set(wantTab);
        }
      });
    }

    keepBugBoardProduct(context, ref, account, location);

    final Widget body;
    switch (viewMode.value) {
      case 'list':
        body = const ZenTaoBugTableView();
      case 'board':
      default:
        body = const ZenTaoBugBoardView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // S5.1 Header Row: Scope dot, name, Bugs · count caption, + New bug button
        ZentaoBugSectionHeader(account: account, location: location),

        ZenTaoBoardToolbar(
          bugs: true,
          modes: modes,
          viewMode: viewMode,
          filtering: !isRelated,
          scopes: [
            AppSegmentedTab(
              label: l.viewAll,
              active: !isRelated,
              onTap: () {
                ref
                    .read(filterStateProvider.notifier)
                    .setSavedView(SavedView.all);
                ref
                    .read(zentaoBugTabProvider.notifier)
                    .set(ZenTaoBugBrowseType.unclosed);
              },
            ),
            AppSegmentedTab(
              label: l.relatedToMe,
              active: isRelated,
              onTap: () {
                // Related to me is a filter of its own: no others on it.
                ref.read(filterStateProvider.notifier)
                  ..clearAll()
                  ..setSavedView(SavedView.related);
                ref
                    .read(zentaoBugTabProvider.notifier)
                    .set(ZenTaoBugBrowseType.relatedToMe);
              },
            ),
          ],
        ),

        // Section Body (Board or Table)
        Expanded(child: body),
      ],
    );
  }
}
