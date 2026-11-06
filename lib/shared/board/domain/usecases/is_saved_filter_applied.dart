import '../entities/filter_state.dart';
import '../value_objects/saved_filter.dart';

/// Whether the filter on screen ([current]) is still exactly what [preset]
/// applied, so its chip can show as the one in effect. Changing any chip
/// afterwards drops the match.
///
/// The workspace is the board's scope, not a criterion (applying a preset keeps
/// it), so it never counts. Nor does a toolbar search typed over a preset saved
/// without one: searching the board does not stop the preset being in effect.
class IsSavedFilterApplied {
  const IsSavedFilterApplied();

  bool call(SavedFilter preset, FilterState current) {
    final saved = preset.filter;
    return saved.copyWith(
          workspaceId: current.workspaceId,
          search: saved.search.trim().isEmpty ? current.search : saved.search,
        ) ==
        current;
  }
}
