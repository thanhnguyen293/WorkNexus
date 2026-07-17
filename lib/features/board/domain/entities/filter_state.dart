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
    @Default('') String search,
  }) = _FilterState;

  bool get hasActiveFilters =>
      providers.isNotEmpty ||
      accountIds.isNotEmpty ||
      projectIds.isNotEmpty ||
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      search.trim().isNotEmpty;

  /// Number of chip-style filters active (excludes free-text search).
  int get activeTokenCount =>
      providers.length +
      accountIds.length +
      projectIds.length +
      statuses.length +
      priorities.length;
}
