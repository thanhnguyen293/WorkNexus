import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../value_objects/saved_view.dart';

part 'filter_state.freezed.dart';

/// The full active filter selection driving the board/list. `workspaceId` is
/// `'all'` or a specific workspace. Set fields get deep-equality from freezed,
/// so Riverpod recomputes derived state only on real changes.
@freezed
abstract class FilterState with _$FilterState {
  const FilterState._();

  const factory FilterState({
    @Default('all') String workspaceId,
    @Default(SavedView.all) SavedView savedView,
    @Default(<ProviderType>{}) Set<ProviderType> providers,
    @Default(<String>{}) Set<String> accountIds,
    @Default(<String>{}) Set<String> projectIds,
    @Default(<UnifiedStatus>{}) Set<UnifiedStatus> statuses,
    @Default(<Priority>{}) Set<Priority> priorities,
    @Default(<int>{}) Set<int> severities,
    @Default(<String>{}) Set<String> assignees,
    @Default(<String>{}) Set<String> reviewers,
    @Default(<String>{}) Set<String> bugTypes,
    @Default(<String>{}) Set<String> resolutions,
    // ZenTao boards: the board column (status) a ticket sits in, who resolved
    // or opened a bug (names), and whether it was confirmed (`'1'` / `'0'`).
    @Default(<String>{}) Set<String> zentaoStatuses,
    @Default(<String>{}) Set<String> resolvers,
    @Default(<String>{}) Set<String> reporters,
    @Default(<String>{}) Set<String> confirmations,
    @Default('') String search,
  }) = _FilterState;

  bool get hasActiveFilters =>
      providers.isNotEmpty ||
      accountIds.isNotEmpty ||
      projectIds.isNotEmpty ||
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      severities.isNotEmpty ||
      assignees.isNotEmpty ||
      reviewers.isNotEmpty ||
      bugTypes.isNotEmpty ||
      resolutions.isNotEmpty ||
      zentaoStatuses.isNotEmpty ||
      resolvers.isNotEmpty ||
      reporters.isNotEmpty ||
      confirmations.isNotEmpty ||
      search.trim().isNotEmpty;

  /// Whether this filter can hide any of a board's tickets: a workspace or a
  /// non-"all" saved view, on top of [hasActiveFilters]. A paged board then
  /// scans further pages for matches instead of trusting a page to fill it.
  bool get narrowsTickets =>
      hasActiveFilters || workspaceId != 'all' || savedView != SavedView.all;

  /// Number of chip-style filters active (excludes free-text search).
  int get activeTokenCount =>
      providers.length +
      accountIds.length +
      projectIds.length +
      statuses.length +
      priorities.length +
      severities.length +
      assignees.length +
      reviewers.length +
      bugTypes.length +
      resolutions.length +
      zentaoStatuses.length +
      resolvers.length +
      reporters.length +
      confirmations.length;
}
