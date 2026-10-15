import '../../../../core/database/database.dart';
import '../../domain/entities/translation_record.dart';
import '../../domain/repositories/translation_repository.dart';
import '../mappers/translation_mappers.dart';

/// Drift-backed [TranslationRepository] — the persisted Vietnamese translation
/// per ticket. Owned by the translation feature (single consumer).
class LocalTranslationRepository implements TranslationRepository {
  LocalTranslationRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<TranslationRecord?> watchTranslation(String ticketId) => _db
      .watchTranslation(ticketId)
      .map((row) => row == null ? null : translationFromRow(row));

  @override
  Future<TranslationRecord?> getTranslation(String ticketId) async {
    final row = await (_db.select(
      _db.translations,
    )..where((t) => t.ticketId.equals(ticketId))).getSingleOrNull();
    return row == null ? null : translationFromRow(row);
  }

  @override
  Future<void> saveTranslation(TranslationRecord record) async {
    await _db
        .into(_db.translations)
        .insertOnConflictUpdate(translationToCompanion(record));
  }
}
