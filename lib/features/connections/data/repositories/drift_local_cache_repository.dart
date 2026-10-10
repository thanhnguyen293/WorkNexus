import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/cache_section.dart';
import '../../domain/repositories/local_cache_repository.dart';

/// Clears cached tables in one transaction, so a failure leaves the cache
/// as it was rather than half-emptied.
class DriftLocalCacheRepository implements LocalCacheRepository {
  DriftLocalCacheRepository(this._db);

  final AppDatabase _db;

  List<TableInfo<Table, Object?>> _tablesOf(CacheSection section) =>
      switch (section) {
        CacheSection.tickets => [
          _db.comments,
          _db.activities,
          _db.tickets,
          _db.projects,
          _db.sourceListSnapshots,
        ],
        CacheSection.dashboard => [
          _db.dashboardSnapshots,
          _db.zenTaoNotifications,
          _db.zenTaoProfiles,
        ],
        CacheSection.chat => [
          _db.chatMessages,
          _db.chatConversations,
          _db.chatUsers,
        ],
        CacheSection.translations => [
          _db.translations,
          _db.chatMessageTranslations,
        ],
      };

  @override
  Future<Result<void>> clear(Set<CacheSection> sections) async {
    try {
      await _db.transaction(() async {
        for (final section in sections) {
          for (final table in _tablesOf(section)) {
            await _db.delete(table).go();
          }
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure('Could not clear the cache: $e', cause: e));
    }
  }
}
