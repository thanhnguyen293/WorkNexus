import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/error/result.dart';
import '../domain/repositories/saved_filter_repository.dart';
import '../domain/usecases/build_saved_filter.dart';
import '../domain/value_objects/saved_filter.dart';
import 'board_providers.dart';

/// The board's saved filter presets, newest first. Watched from the DB (the
/// source of truth), so a save or delete shows up everywhere at once.
final savedFiltersProvider = StreamProvider<List<SavedFilter>>(
  (ref) => getIt<SavedFilterRepository>().watchSavedFilters(),
);

/// Commands over the presets. CRUD pass-through to the repository *interface*
/// (CLAUDE.md 2.4 exception); the one piece of real logic — naming and
/// overwrite-by-name — lives in [BuildSavedFilter].
class SavedFilterController extends Notifier<void> {
  @override
  void build() {}

  /// Stores the filter currently on screen under [name]. Reusing an existing
  /// name overwrites that preset; a blank name is ignored (the UI keeps Save
  /// disabled until there is one).
  Future<Result<void>> saveCurrent(String name) async {
    final preset = const BuildSavedFilter()(
      name: name,
      filter: ref.read(filterStateProvider),
      existing: ref.read(savedFiltersProvider).value ?? const <SavedFilter>[],
      now: DateTime.now(),
    );
    if (preset == null) return const Ok(null);
    return getIt<SavedFilterRepository>().upsert(preset);
  }

  Future<Result<void>> delete(String id) =>
      getIt<SavedFilterRepository>().delete(id);

  void apply(SavedFilter preset) =>
      ref.read(filterStateProvider.notifier).applyPreset(preset.filter);
}

final savedFilterControllerProvider =
    NotifierProvider<SavedFilterController, void>(SavedFilterController.new);
