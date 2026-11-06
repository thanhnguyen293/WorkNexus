import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/usecases/derive_board_facets.dart';

/// The heading of a facet group, as the popover and the filter chips name it.
String facetHeader(AppL10n l, BoardFacetKind kind) => switch (kind) {
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
  BoardFacetKind.module => l.fieldModule,
};

/// How an option of a facet group reads when nothing better names it.
String facetLabel(AppL10n l, BoardFacetKind kind, String value) =>
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
      // Named by the catalog; a module it lacks (since deleted) by its id.
      BoardFacetKind.module => value,
    };

/// Whether [value] of facet [kind] is picked in [f].
bool facetActive(FilterState f, BoardFacetKind kind, String value) =>
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
      BoardFacetKind.module => f.modules.contains(value),
    };
