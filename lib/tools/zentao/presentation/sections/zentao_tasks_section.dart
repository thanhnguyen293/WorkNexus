import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/coming_soon_view.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/domain/value_objects/saved_view.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/board/presentation/widgets/filters_button.dart';
import '../providers/zentao_board_providers.dart';
import '../util/keep_task_board_scope.dart';
import '../widgets/zentao_status_filter_option.dart';
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
    final c = context.colors;
    final s = context.spacing;
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('list');
    keepTaskBoardScope(context, ref, account, location);

    final Widget body;
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

    final filter = ref.watch(filterStateProvider);
    final isMine = filter.savedView == SavedView.mine;
    final dueThisWeek = ref.watch(zentaoTaskDueThisWeekProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // S5.1 Header Row: Scope dot, name, Tasks · count caption, + New task button
        ZentaoTaskSectionHeader(account: account, location: location),

        // View Mode Tabs: List, Kanban, Calendar, Gantt (underline tab row)
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: context.hairlineSide),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.xl),
            child: Row(
              children: [
                for (final m in modes)
                  _ModeTab(
                    label: m.label(l),
                    selected: m.id == viewMode,
                    onTap: () =>
                        ref.read(appNavProvider.notifier).setViewMode(m.id),
                  ),
              ],
            ),
          ),
        ),

        // Filter Bar: Quick filters (All, Assigned to me, Due this week) + Sprint/Status dropdowns
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: context.hairlineSide),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.xs),
            child: Row(
              children: [
                _FilterChip(
                  label: l.viewAll,
                  selected: !isMine && !dueThisWeek,
                  onTap: () {
                    ref
                        .read(filterStateProvider.notifier)
                        .setSavedView(SavedView.all);
                    ref.read(zentaoTaskDueThisWeekProvider.notifier).set(false);
                  },
                ),
                SizedBox(width: s.xs),
                _FilterChip(
                  label: l.assignedToMe,
                  selected: isMine && !dueThisWeek,
                  onTap: () {
                    ref
                        .read(filterStateProvider.notifier)
                        .setSavedView(SavedView.mine);
                    ref.read(zentaoTaskDueThisWeekProvider.notifier).set(false);
                  },
                ),
                SizedBox(width: s.xs),
                _FilterChip(
                  label: l.dueThisWeek,
                  selected: dueThisWeek,
                  onTap: () {
                    ref
                        .read(filterStateProvider.notifier)
                        .setSavedView(SavedView.all);
                    ref.read(zentaoTaskDueThisWeekProvider.notifier).set(true);
                  },
                ),
                SizedBox(width: s.sm),
                FiltersButton(
                  statusOption: zentaoStatusFilterOption(bugBoard: false),
                ),
              ],
            ),
          ),
        ),

        // Section Body (Table, Kanban, or ComingSoon)
        Expanded(child: body),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return HoverSurface(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      border: Border(
        bottom: BorderSide(
          color: selected ? c.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: context.typography.bodySm.copyWith(
          color: selected ? c.textPrimary : c.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return HoverSurface(
      onTap: onTap,
      selected: selected,
      borderRadius: BorderRadius.circular(context.radii.pill),
      color: selected ? c.selectionFill : c.surfaceSubtle,
      border: selected
          ? Border.all(color: c.accent.withValues(alpha: 0.35))
          : null,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xxs),
      child: Text(
        label,
        style: context.typography.caption.copyWith(
          color: selected ? c.accent : c.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
