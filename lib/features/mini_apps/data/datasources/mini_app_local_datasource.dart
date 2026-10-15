import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to the user's mini apps ([MiniApps]).
class MiniAppLocalDatasource {
  const MiniAppLocalDatasource(this._db);

  final AppDatabase _db;

  Stream<List<MiniAppRow>> watchAll() => (_db.select(
    _db.miniApps,
  )..orderBy([(a) => OrderingTerm.asc(a.position)])).watch();

  Future<void> save(MiniAppsCompanion row) =>
      _db.into(_db.miniApps).insertOnConflictUpdate(row);

  Future<void> updateLastUrl(String id, String url) =>
      (_db.update(_db.miniApps)..where((a) => a.id.equals(id))).write(
        MiniAppsCompanion(lastUrl: Value(url)),
      );

  /// Gives each app in [ids] its index as position, in one write.
  Future<void> updatePositions(List<String> ids) => _db.transaction(() async {
    for (final (i, id) in ids.indexed) {
      await (_db.update(_db.miniApps)..where((a) => a.id.equals(id))).write(
        MiniAppsCompanion(position: Value(i)),
      );
    }
  });

  /// Removes the app with its remembered permissions.
  Future<void> delete(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.miniAppPermissions,
    )..where((p) => p.miniAppId.equals(id))).go();
    await (_db.delete(_db.miniApps)..where((a) => a.id.equals(id))).go();
  });
}
