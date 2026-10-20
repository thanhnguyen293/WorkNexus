import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/coming_soon_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/domain/value_objects/saved_view.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';
import '../util/keep_task_board_scope.dart';
import '../widgets/zentao_board_toolbar.dart';
import '../widgets/zentao_task_board_view.dart';
import '../widgets/zentao_task_section_header.dart';
import '../widgets/zentao_task_table_view.dart';

/// The L5 Viewport section for ZenTao Tasks, formatted after slide 02 (specs.md §5.1, §5.2).
/// Displays Viewport Header (Scope dot, name, count, + New task), View Mode Tabs,
/// Quick Filter Chips (All, Assigned to me, Due this week), and Dropdown Filter Chips.
class ZentaoTasksSection extends ConsumerWidget {
  const ZentaoTasksSection({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  static List<ToolViewMode> get modes => [
    ToolViewMode(
      id: const ViewModeId('list'),
      label: (l) => l.viewList,
      icon: LucideIcons.list300,
    ),
    ToolViewMode(
      id: const ViewModeId('kanban'),
      label: (l) => l.viewKanban,
      icon: LucideIcons.kanban300,
    ),
    ToolViewMode(
      id: const ViewModeId('calendar'),
      label: (l) => l.viewCalendar,
      icon: LucideIcons.calendar300,
    ),
    ToolViewMode(
      id: const ViewModeId('gantt'),
      label: (l) => l.viewGantt,
      icon: LucideIcons.chartGantt300,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('list');
    keepTaskBoardScope(context, ref, account, location);

    final Widget body;
    if (!taskBoardHasExecution(ref, account, location)) {
      // Until an execution is picked (or none could be): tasks are listed
      // per execution only.
      body = AppStateView.empty(
        icon: LucideIcons.listChecks300,
        title: l.zentaoPickExecution,
      );
    } else {
      switch (viewMode.value) {
        case 'kanban':
          body = const ZenTaoTaskBoardView();
        case 'calendar':
          body = ComingSoonView(
            icon: LucideIcons.calendar300,
            title: l.viewCalendar,
            body: 'Calendar view for ZenTao tasks is coming soon.',
            actionLabel: l.switchToView(l.viewList),
            onAction: () => ref
                .read(appNavProvider.notifier)
                .setViewMode(const ViewModeId('list')),
          );
        case 'gantt':
          body = ComingSoonView(
            icon: LucideIcons.chartGantt300,
            title: l.viewGantt,
            body: 'Gantt chart view for ZenTao tasks is coming soon.',
            actionLabel: l.switchToView(l.viewKanban),
            onAction: () => ref
                .read(appNavProvider.notifier)
                .setViewMode(const ViewModeId('kanban')),
          );
        case 'list':
        default:
          body = const ZenTaoTaskTableView();
      }
    }

    final filter = ref.watch(filterStateProvider);
    final isRelated = filter.savedView == SavedView.related;
    final dueThisWeek = ref.watch(zentaoTaskDueThisWeekProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // S5.1 Header Row: Scope dot, name, Tasks · count caption, + New task button
        ZentaoTaskSectionHeader(account: account, location: location),

        ZenTaoBoardToolbar(
          bugs: false,
          modes: modes,
          viewMode: viewMode,
          scopes: [
            AppSegmentedTab(
              label: l.viewAll,
              active: !isRelated && !dueThisWeek,
              onTap: () {
                ref
                    .read(filterStateProvider.notifier)
                    .setSavedView(SavedView.all);
                ref.read(zentaoTaskDueThisWeekProvider.notifier).set(false);
              },
            ),
            AppSegmentedTab(
              label: l.relatedToMe,
              active: isRelated && !dueThisWeek,
              onTap: () {
                ref
                    .read(filterStateProvider.notifier)
                    .setSavedView(SavedView.related);
                ref.read(zentaoTaskDueThisWeekProvider.notifier).set(false);
              },
            ),
            AppSegmentedTab(
              label: l.dueThisWeek,
              active: dueThisWeek,
              onTap: () {
                ref
                    .read(filterStateProvider.notifier)
                    .setSavedView(SavedView.all);
                ref.read(zentaoTaskDueThisWeekProvider.notifier).set(true);
              },
            ),
          ],
        ),

        // Section Body (Table, Kanban, or ComingSoon)
        Expanded(child: body),
      ],
    );
  }
}
