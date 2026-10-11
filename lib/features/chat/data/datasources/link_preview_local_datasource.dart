import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access for stored link previews (CLAUDE.md 3.4).
class LinkPreviewLocalDatasource {
  LinkPreviewLocalDatasource(this._db);

  final AppDatabase _db;

  Future<ChatLinkPreviewRow?> find(String url) => (_db.select(
    _db.chatLinkPreviews,
  )..where((p) => p.url.equals(url))).getSingleOrNull();

  Future<void> save(ChatLinkPreviewsCompanion row) =>
      _db.into(_db.chatLinkPreviews).insertOnConflictUpdate(row);

  /// Drops previews fetched before [cutoff].
  Future<void> deleteOlderThan(DateTime cutoff) => (_db.delete(
    _db.chatLinkPreviews,
  )..where((p) => p.fetchedAt.isSmallerThanValue(cutoff))).go();
}
