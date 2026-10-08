import '../../../../core/error/result.dart';
import '../value_objects/saved_filter.dart';

/// Storage for the board's named filter presets. Implemented in the board
/// feature's `data/` layer over drift (local-first: the DB is the source of
/// truth and the UI watches it).
abstract class SavedFilterRepository {
  /// All presets, newest first, re-emitted on every change.
  Stream<List<SavedFilter>> watchSavedFilters();

  /// Inserts [filter], or replaces the preset with the same id.
  Future<Result<void>> upsert(SavedFilter filter);

  Future<Result<void>> delete(String id);
}
