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
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/domain/value_objects/saved_view.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/board/presentation/widgets/filters_button.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import '../providers/zentao_board_providers.dart';
import '../widgets/zentao_bug_board_view.dart';
import '../widgets/zentao_bug_section_header.dart';
import '../widgets/zentao_bug_table_view.dart';
import '../widgets/zentao_status_filter_option.dart';

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
    final c = context.colors;
    final s = context.spacing;
    final viewMode =
        location.viewModes[location.section] ?? const ViewModeId('board');

    final filter = ref.watch(filterStateProvider);
    final isMine = filter.savedView == SavedView.mine;

    final prods = ref.watch(zentaoProductsProvider(account.id)).asData?.value;
    if (location.scopeId != null &&
        prods != null &&
        ref.read(selectedZenTaoProductProvider)?.productId !=
            location.scopeId) {
      final p = prods.where((item) => item.id == location.scopeId).firstOrNull;
      if (p != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedZenTaoProductProvider.notifier).select(p);
        });
      }
    }

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

        // View Mode Tabs: Board, List (underline tab row)
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

        // Filter Bar: Quick filters (All, Assigned to me) + Filter button
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
                  selected: !isMine,
                  onTap: () {
                    ref
                        .read(filterStateProvider.notifier)
                        .setSavedView(SavedView.all);
                    ref
                        .read(zentaoBugTabProvider.notifier)
                        .set(ZenTaoBugBrowseType.unclosed);
                  },
                ),
                SizedBox(width: s.xs),
                _FilterChip(
                  label: l.assignedToMe,
                  selected: isMine,
                  onTap: () {
                    ref
                        .read(filterStateProvider.notifier)
                        .setSavedView(SavedView.mine);
                    ref
                        .read(zentaoBugTabProvider.notifier)
                        .set(ZenTaoBugBrowseType.assignedToMe);
                  },
                ),
                SizedBox(width: s.sm),
                FiltersButton(
                  statusOption: zentaoStatusFilterOption(bugBoard: true),
                ),
              ],
            ),
          ),
        ),

        // Section Body (Board or Table)
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
