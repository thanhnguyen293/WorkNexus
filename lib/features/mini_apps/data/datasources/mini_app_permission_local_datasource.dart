import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to the remembered mini app permissions ([MiniAppPermissions]).
class MiniAppPermissionLocalDatasource {
  const MiniAppPermissionLocalDatasource(this._db);

  final AppDatabase _db;

  Stream<List<MiniAppPermissionRow>> watch(String miniAppId) => (_db.select(
    _db.miniAppPermissions,
  )..where((p) => p.miniAppId.equals(miniAppId))).watch();

  Future<MiniAppPermissionRow?> read(String miniAppId, String kind) =>
      (_db.select(_db.miniAppPermissions)
            ..where((p) => p.miniAppId.equals(miniAppId) & p.kind.equals(kind)))
          .getSingleOrNull();

  Future<void> save(MiniAppPermissionsCompanion row) =>
      _db.into(_db.miniAppPermissions).insertOnConflictUpdate(row);

  Future<void> clear(String miniAppId, String kind) => (_db.delete(
    _db.miniAppPermissions,
  )..where((p) => p.miniAppId.equals(miniAppId) & p.kind.equals(kind))).go();
}
