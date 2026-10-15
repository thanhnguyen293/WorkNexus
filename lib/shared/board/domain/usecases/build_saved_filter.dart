import '../entities/filter_state.dart';
import '../value_objects/saved_filter.dart';

/// Turns "save the current filter under this name" into a [SavedFilter].
///
/// Reusing an existing name overwrites that preset (rather than growing a pile
/// of same-named entries), so re-saving is how you update one. Returns null for
/// a blank name — the UI keeps its Save action disabled until there is one.
class BuildSavedFilter {
  const BuildSavedFilter();

  SavedFilter? call({
    required String name,
    required FilterState filter,
    required List<SavedFilter> existing,
    required DateTime now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    String? reusedId;
    for (final saved in existing) {
      if (saved.name.toLowerCase() == lower) {
        reusedId = saved.id;
        break;
      }
    }
    return SavedFilter(
      id: reusedId ?? 'sf-${now.microsecondsSinceEpoch}',
      name: trimmed,
      filter: filter,
      createdAt: now,
    );
  }
}
