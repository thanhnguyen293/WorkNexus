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
import '../providers/board_providers.dart';
import 'filter_option_group.dart';
import 'filter_people_block.dart';

/// Data-derived facet groups for the active ZenTao / GitLab-MR board.
///
/// With the owning tool's [catalog] every choice is listed, carried by a loaded
/// ticket or not; without it, what the tickets carry. A group as long as a
/// team (assignees, reviewers) turns into a dropdown ([FilterOptionsGroup]).
class FacetFilterGroups extends ConsumerWidget {
  const FacetFilterGroups({
    super.key,
    this.statusOption,
    this.catalog,
    this.onPick,
  });

  /// Draws a status option the way its tool names and colours that status (a
  /// board column); without it a status shows as its plain name.
  final FacetStatusOption? statusOption;

  /// Every choice of each dimension, from the tool that owns the board (see
  /// [BoardFacetCatalog]); without it the options are what the tickets carry.
  final BoardFacetCatalog? catalog;

  /// Called after each option the user picks or drops — the owning board
  /// moves to its All view, so a filter applies to every ticket.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final facets = ref.watch(boardFacetsProvider(catalog));

    if (facets.groups.isEmpty) {
      return Text(
        l.noBoardFilters,
        style: context.typography.meta.copyWith(color: c.textTertiary),
      );
    }
    List<FilterChipOption> optionsOf(BoardFacetGroup g) => [
      for (final o in g.options)
        if (g.kind == BoardFacetKind.status && statusOption != null)
          statusOption!(
            context,
            o,
            active: f.zentaoStatuses.contains(o.value),
            onTap: () {
              ctrl.toggleZenTaoStatus(o.value);
              onPick?.call();
            },
          )
        else
          FilterChipOption(
            label: o.label ?? _facetLabel(l, g.kind, o.value),
            count: o.count > 0 ? o.count : null,
            active: _facetActive(f, g.kind, o.value),
            dotColor: _facetDot(c, g.kind, o.value),
            onTap: () {
              _facetToggle(ctrl, g.kind, o.value);
              onPick?.call();
            },
          ),
    ];
    final people = [
      for (final g in facets.groups)
        if (_people.contains(g.kind)) g,
    ];
    // Two or more people groups are one question (any of them matching), so
    // they share a box where the first of them stood.
    final together = people.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in facets.groups)
          if (together && identical(g, people.first))
            FilterPeopleBlock(
              groups: [
                for (final p in people)
                  (label: _facetHeader(l, p.kind), options: optionsOf(p)),
              ],
            )
          else if (!together || !people.contains(g))
            FilterOptionsGroup(
              label: _facetHeader(l, g.kind),
              // A person is found by name: a dropdown however few there are.
              dropdownThreshold: _people.contains(g.kind) ? 0 : 8,
              options: optionsOf(g),
            ),
      ],
    );
  }
}

/// The groups that pick people; a ticket passes them when any one matches (see
/// `FilterTickets`).
const _people = {
  BoardFacetKind.assignee,
  BoardFacetKind.resolvedBy,
  BoardFacetKind.openedBy,
};

/// Builds a status facet option as the tool that owns the board shows it: named
/// and coloured like its board column (the table's Status cell).
typedef FacetStatusOption =
    FilterChipOption Function(
      BuildContext context,
      BoardFacetOption option, {
      required bool active,
      required VoidCallback onTap,
    });

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
      // Drawn by [FacetFilterGroups.statusOption]; the plain name otherwise.
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
