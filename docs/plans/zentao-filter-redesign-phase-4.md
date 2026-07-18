# Plan: zentao-filter-redesign phase 4 — contextual FilterPopover

## Context

Rewrite `FilterPopover` so it switches on `viewModeProvider`: ZenTao bug/task
boards show data-derived facet groups (from `boardFacetsProvider`); the generic
board/list keep the existing provider/account/project/status/priority groups
unchanged. Depends on phases 1–3. This is a declarative UI file — no TDD; write it
directly. It stays ≤300 lines (rule 6.1).

## Constraints

- NO edits outside `lib/features/board/presentation/widgets/filter_popover.dart`.
- Near-miss (do NOT touch): `active_tokens.dart` (phase 5), `chrome_bar.dart`,
  `board_page.dart`. They already open/anchor the popover correctly.
- Use design tokens only — no raw `Color(0x…)`/`Colors.*`, no magic numbers beyond
  what the current file already uses (the `26`/`7` chip sizes are pre-existing and
  kept verbatim). All labels via l10n / `zentao_labels.dart` (rules 7.2, 7.3).
- Escape hatch: if the l10n getters `l.assignee`/`l.severity`/`l.bugType`/
  `l.resolution`/`l.unassigned`/`l.noBoardFilters` do not exist (phase 3 not run),
  or `boardFacetsProvider`/`BoardFacetKind` are missing (phases 2–3 not run) →
  STOP and report; do not stub them.

## Steps

### Step 1: rewrite the file — `lib/features/board/presentation/widgets/filter_popover.dart`

- Current state (first lines, to confirm the target file):
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../../core/di/providers.dart';
  ...
  /// The advanced-filter dropdown: chip groups for provider/account/project/
  /// status/priority.
  class FilterPopover extends ConsumerWidget {
  ```
- Convention exemplar: keep the existing `_Group`/`_Chip` widget style; the switch
  on `ViewMode` mirrors `board_page.dart`'s `switch (mode)`; facet helper switches
  mirror `semantic.dart`'s `switch` expressions.
- Replace the **entire file** with:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  import '../../../../core/di/providers.dart';
  import '../../../../core/domain/value_objects/priority.dart';
  import '../../../../core/domain/value_objects/provider_type.dart';
  import '../../../../core/domain/value_objects/unified_status.dart';
  import '../../../../core/theme/app_borders.dart';
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

      if (facets.groups.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.xl),
          child: Text(
            l.noBoardFilters,
            style: context.typography.meta.copyWith(color: c.textTertiary),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in facets.groups)
            _Group(
              label: _facetHeader(l, g.kind),
              children: [
                for (final o in g.options)
                  _Chip(
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
          _Group(
            label: l.provider,
            children: [
              for (final p in ProviderType.values)
                _Chip(
                  label: p.displayName,
                  active: f.providers.contains(p),
                  onTap: () => ctrl.toggleProvider(p),
                ),
            ],
          ),
          _Group(
            label: l.account,
            children: [
              for (final a in lookups.accounts.values)
                _Chip(
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
          _Group(
            label: l.project,
            children: [
              for (final p in lookups.projects.values)
                _Chip(
                  label: p.name,
                  active: f.projectIds.contains(p.id),
                  onTap: () => ctrl.toggleProject(p.id),
                ),
            ],
          ),
          _Group(
            label: l.status,
            children: [
              for (final s in UnifiedStatus.columns)
                _Chip(
                  label: statusLabel(l, s),
                  active: f.statuses.contains(s),
                  dotColor: statusColor(c, s),
                  onTap: () => ctrl.toggleStatus(s),
                ),
            ],
          ),
          _Group(
            label: l.priority,
            children: [
              for (final p in Priority.values)
                _Chip(
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
        BoardFacetKind.priority => priorityColor(c, Priority.values.byName(value)),
        _ => null,
      };

  bool _facetActive(FilterState f, BoardFacetKind kind, String value) =>
      switch (kind) {
        BoardFacetKind.assignee => f.assignees.contains(value),
        BoardFacetKind.severity => f.severities.contains(int.tryParse(value) ?? -1),
        BoardFacetKind.priority =>
          f.priorities.contains(Priority.values.byName(value)),
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

  class _Group extends StatelessWidget {
    const _Group({required this.label, required this.children});
    final String label;
    final List<Widget> children;

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: context.typography.label.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
            SizedBox(height: context.spacing.sm),
            Wrap(
              spacing: context.spacing.sm,
              runSpacing: context.spacing.sm,
              children: children,
            ),
          ],
        ),
      );
    }
  }

  class _Chip extends StatelessWidget {
    const _Chip({
      required this.label,
      required this.active,
      required this.onTap,
      this.dotColor,
      this.count,
    });
    final String label;
    final bool active;
    final VoidCallback onTap;
    final Color? dotColor;
    final int? count;

    @override
    Widget build(BuildContext context) {
      final c = context.colors;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
          decoration: BoxDecoration(
            color: active ? c.selectionFill : c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.pill),
            border: context.borders.showOutline
                ? Border.all(color: c.border)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.spacing.xs),
              ],
              Text(
                label,
                style: context.typography.meta.copyWith(
                  fontWeight: FontWeight.w500,
                  color: active ? c.textPrimary : c.textSecondary,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: context.spacing.xs),
                Text(
                  '$count',
                  style: context.typography.meta.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
  ```
- Verify: `fvm dart analyze lib/features/board/presentation/widgets/filter_popover.dart`
  → expected: "No issues found!", exit 0.

### Step 2: line-count check (rule 6.1)

- Verify: `awk 'END {print NR}' lib/features/board/presentation/widgets/filter_popover.dart`
  → expected: a number ≤ 300.

## Final verification

- `fvm dart analyze lib/features/board` → "No issues found!", exit 0.
- `fvm flutter test test/widget test/domain` → "All tests passed!", exit 0.
- Manual (optional, if running the app): open a ZenTao product → Filters shows
  Assignee/Severity/Priority/Type/Resolution with counts; open an execution →
  Assignee/Priority; switch to generic board/list → the old 5 groups.

## Out of scope

- Do NOT change `ActiveTokens` (phase 5) — active-chip removal still works via the
  existing provider/account/status/priority tokens; the new facet tokens arrive in
  phase 5.
- Do NOT add server-side filtering, saved custom filters, or a "hide closed"
  toggle — not in this plan.
- Do NOT alter the popover's size, anchor, or the scrim in `board_page.dart`.
