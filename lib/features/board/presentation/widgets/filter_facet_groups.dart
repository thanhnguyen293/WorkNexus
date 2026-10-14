import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/usecases/derive_board_facets.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../../domain/value_objects/zentao_task_column.dart';
import '../board_providers.dart';
import 'filter_option_group.dart';
import 'zentao_bug_column_parts.dart';
import 'zentao_task_column_parts.dart';

/// Data-derived facet groups for the active ZenTao / GitLab-MR board.
///
/// Every group is searchable: assignee and reviewer lists in particular are as
/// long as the team, and [SearchableFilterGroup] only shows the box once a group
/// is big enough to need one.
class FacetFilterGroups extends ConsumerWidget {
  const FacetFilterGroups({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final facets = ref.watch(boardFacetsProvider);
    final bugBoard = ref.watch(viewModeProvider) == ViewMode.zentaoBugs;

    if (facets.groups.isEmpty) {
      return Text(
        l.noBoardFilters,
        style: context.typography.meta.copyWith(color: c.textTertiary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in facets.groups)
          SearchableFilterGroup(
            label: _facetHeader(l, g.kind),
            options: [
              for (final o in g.options)
                if (g.kind == BoardFacetKind.status)
                  _statusOption(
                    context,
                    o,
                    bugBoard: bugBoard,
                    active: f.zentaoStatuses.contains(o.value),
                    onTap: () => ctrl.toggleZenTaoStatus(o.value),
                  )
                else
                  FilterChipOption(
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

/// A status option, named and coloured like its board column (the table's
/// Status cell).
FilterChipOption _statusOption(
  BuildContext context,
  BoardFacetOption option, {
  required bool bugBoard,
  required bool active,
  required VoidCallback onTap,
}) {
  final bug = bugBoard
      ? ZenTaoBugColumn.values.asNameMap()[option.value]
      : null;
  final task = bugBoard
      ? null
      : ZenTaoTaskColumn.values.asNameMap()[option.value];
  final (label, color) = switch ((bug, task)) {
    (final bug?, _) => bugColumnVisual(context, bug),
    (_, final task?) => taskColumnVisual(context, task),
    _ => (option.value, null),
  };
  return FilterChipOption(
    label: label,
    count: option.count,
    active: active,
    dotColor: color,
    onTap: onTap,
  );
}

String _facetHeader(AppL10n l, BoardFacetKind kind) => switch (kind) {
  BoardFacetKind.status => l.status,
  BoardFacetKind.resolvedBy => l.fieldResolvedBy,
  BoardFacetKind.openedBy => l.openedBy,
  BoardFacetKind.confirmed => l.fieldConfirmation,
  BoardFacetKind.assignee => l.assignee,
  BoardFacetKind.reviewer => l.reviewers,
  BoardFacetKind.severity => l.severity,
  BoardFacetKind.priority => l.priority,
  BoardFacetKind.bugType => l.bugType,
  BoardFacetKind.resolution => l.resolution,
};

String _facetLabel(AppL10n l, BoardFacetKind kind, String value) =>
    switch (kind) {
      // Drawn by [_statusOption]; kept for a total switch.
      BoardFacetKind.status => value,
      BoardFacetKind.resolvedBy || BoardFacetKind.openedBy => value,
      BoardFacetKind.confirmed => value == '1' ? l.confirmed : l.bugUnconfirmed,
      BoardFacetKind.assignee => value.isEmpty ? l.unassigned : value,
      BoardFacetKind.reviewer => value.isEmpty ? l.unassigned : value,
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
      BoardFacetKind.status => f.zentaoStatuses.contains(value),
      BoardFacetKind.resolvedBy => f.resolvers.contains(value),
      BoardFacetKind.openedBy => f.reporters.contains(value),
      BoardFacetKind.confirmed => f.confirmations.contains(value),
      BoardFacetKind.assignee => f.assignees.contains(value),
      BoardFacetKind.reviewer => f.reviewers.contains(value),
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
    case BoardFacetKind.status:
      ctrl.toggleZenTaoStatus(value);
    case BoardFacetKind.resolvedBy:
      ctrl.toggleResolver(value);
    case BoardFacetKind.openedBy:
      ctrl.toggleReporter(value);
    case BoardFacetKind.confirmed:
      ctrl.toggleConfirmation(value);
    case BoardFacetKind.assignee:
      ctrl.toggleAssignee(value);
    case BoardFacetKind.reviewer:
      ctrl.toggleReviewer(value);
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
