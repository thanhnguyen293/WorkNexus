import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/usecases/derive_board_facets.dart';
import '../board_providers.dart';
import 'filter_chip.dart';

/// The advanced-filter dropdown. Context-aware: ZenTao bug/task boards show
/// data-derived facet groups; the generic board/list show the cross-provider
/// groups (provider/account/project/status/priority).
class FilterPopover extends ConsumerWidget {
  const FilterPopover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    return _PopoverShell(
      child: switch (mode) {
        ViewMode.zentaoBugs || ViewMode.zentaoTasks => const _FacetFilters(),
        ViewMode.board || ViewMode.list => const _GenericFilters(),
      },
    );
  }
}

class _PopoverShell extends StatelessWidget {
  const _PopoverShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.borderStrong),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl2,
        context.spacing.xl,
        context.spacing.xl2,
        context.spacing.xl2,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Data-derived facet groups for the active ZenTao board.
class _FacetFilters extends ConsumerWidget {
  const _FacetFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final facets = ref.watch(boardFacetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facets.groups.isEmpty)
          Text(
            l.noBoardFilters,
            style: context.typography.meta.copyWith(color: c.textTertiary),
          )
        else
          for (final g in facets.groups)
            FilterGroup(
              label: _facetHeader(l, g.kind),
              children: [
                for (final o in g.options)
                  FilterOptionChip(
                    label: _facetLabel(l, g.kind, o.value),
                    count: o.count,
                    active: _facetActive(f, g.kind, o.value),
                    dotColor: _facetDot(c, g.kind, o.value),
                    onTap: () => _facetToggle(ctrl, g.kind, o.value),
                  ),
              ],
            ),
      ],
    );
  }
}

/// The cross-provider groups used by the generic board/list views.
class _GenericFilters extends ConsumerWidget {
  const _GenericFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final lookups = ref.watch(lookupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterGroup(
          label: l.provider,
          children: [
            for (final p in ProviderType.values)
              FilterOptionChip(
                label: p.displayName,
                active: f.providers.contains(p),
                onTap: () => ctrl.toggleProvider(p),
              ),
          ],
        ),
        FilterGroup(
          label: l.account,
          children: [
            for (final a in lookups.accounts.values)
              FilterOptionChip(
                label: a.handle,
                active: f.accountIds.contains(a.id),
                dotColor: switch (lookups.workspaces[a.workspaceId]) {
                  final ws? => Color(ws.colorValue),
                  null => c.workspaceFallback,
                },
                onTap: () => ctrl.toggleAccount(a.id),
              ),
          ],
        ),
        FilterGroup(
          label: l.project,
          children: [
            for (final p in lookups.projects.values)
              FilterOptionChip(
                label: p.name,
                active: f.projectIds.contains(p.id),
                onTap: () => ctrl.toggleProject(p.id),
              ),
          ],
        ),
        FilterGroup(
          label: l.status,
          children: [
            for (final s in UnifiedStatus.columns)
              FilterOptionChip(
                label: statusLabel(l, s),
                active: f.statuses.contains(s),
                dotColor: statusColor(c, s),
                onTap: () => ctrl.toggleStatus(s),
              ),
          ],
        ),
        FilterGroup(
          label: l.priority,
          children: [
            for (final p in Priority.values)
              FilterOptionChip(
                label: priorityName(l, p),
                active: f.priorities.contains(p),
                dotColor: priorityColor(c, p),
                onTap: () => ctrl.togglePriority(p),
              ),
          ],
        ),
      ],
    );
  }
}

String _facetHeader(AppL10n l, BoardFacetKind kind) => switch (kind) {
  BoardFacetKind.assignee => l.assignee,
  BoardFacetKind.severity => l.severity,
  BoardFacetKind.priority => l.priority,
  BoardFacetKind.bugType => l.bugType,
  BoardFacetKind.resolution => l.resolution,
};

String _facetLabel(AppL10n l, BoardFacetKind kind, String value) =>
    switch (kind) {
      BoardFacetKind.assignee => value.isEmpty ? l.unassigned : value,
      BoardFacetKind.severity =>
        zentaoSeverityLabel(int.tryParse(value)) ?? value,
      BoardFacetKind.priority => priorityName(l, Priority.values.byName(value)),
      BoardFacetKind.bugType => zentaoBugTypeLabel(value) ?? value,
      BoardFacetKind.resolution => zentaoResolutionLabel(value) ?? value,
    };

Color? _facetDot(AppColors c, BoardFacetKind kind, String value) =>
    switch (kind) {
      BoardFacetKind.severity => severityColor(c, int.tryParse(value)),
      BoardFacetKind.priority => priorityColor(
        c,
        Priority.values.byName(value),
      ),
      _ => null,
    };

bool _facetActive(FilterState f, BoardFacetKind kind, String value) =>
    switch (kind) {
      BoardFacetKind.assignee => f.assignees.contains(value),
      BoardFacetKind.severity => f.severities.contains(
        int.tryParse(value) ?? -1,
      ),
      BoardFacetKind.priority => f.priorities.contains(
        Priority.values.byName(value),
      ),
      BoardFacetKind.bugType => f.bugTypes.contains(value),
      BoardFacetKind.resolution => f.resolutions.contains(value),
    };

void _facetToggle(FilterController ctrl, BoardFacetKind kind, String value) {
  switch (kind) {
    case BoardFacetKind.assignee:
      ctrl.toggleAssignee(value);
    case BoardFacetKind.severity:
      ctrl.toggleSeverity(int.tryParse(value) ?? -1);
    case BoardFacetKind.priority:
      ctrl.togglePriority(Priority.values.byName(value));
    case BoardFacetKind.bugType:
      ctrl.toggleBugType(value);
    case BoardFacetKind.resolution:
      ctrl.toggleResolution(value);
  }
}
