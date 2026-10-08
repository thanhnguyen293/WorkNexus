import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/saved_filter_repository.dart';
import '../../domain/value_objects/saved_filter.dart';
import '../mappers/saved_filter_mapper.dart';

/// Drift-backed [SavedFilterRepository]: the board's filter presets live in the
/// local DB (the app's source of truth), so the popover watches them and every
/// change shows up without a manual refresh.
///
/// Writes map drift exceptions to a [Failure] here (CLAUDE.md 11.1) so a failed
/// save can't reach the UI as an unhandled async error — or, worse, as a dialog
/// that closes as though it had worked.
class LocalSavedFilterRepository implements SavedFilterRepository {
  LocalSavedFilterRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<SavedFilter>> watchSavedFilters() => _db.watchSavedFilters().map(
    (rows) => rows.map(savedFilterFromRow).toList(),
  );

  @override
  Future<Result<void>> upsert(SavedFilter filter) => _guard(() async {
    final companion = savedFilterToCompanion(filter);
    await _db
        .into(_db.savedFilters)
        .insert(companion, onConflict: DoUpdate((_) => companion));
  }, 'Could not save the filter');

  @override
  Future<Result<void>> delete(String id) => _guard(
    () => (_db.delete(_db.savedFilters)..where((f) => f.id.equals(id))).go(),
    'Could not delete the filter',
  );

  Future<Result<void>> _guard(
    Future<void> Function() write,
    String message,
  ) async {
    try {
      await write();
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure('$message: $e', cause: e));
    }
  }
}
