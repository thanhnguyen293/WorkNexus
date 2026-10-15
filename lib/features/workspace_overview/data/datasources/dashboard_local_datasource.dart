import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to the stored dashboard replies ([DashboardSnapshots]).
class DashboardLocalDatasource {
  const DashboardLocalDatasource(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$DashboardSnapshotsTable, DashboardSnapshotRow>
  _byAccount(String accountId) =>
      _db.select(_db.dashboardSnapshots)
        ..where((s) => s.accountId.equals(accountId));

  Stream<DashboardSnapshotRow?> watch(String accountId) =>
      _byAccount(accountId).watchSingleOrNull();

  Future<DashboardSnapshotRow?> read(String accountId) =>
      _byAccount(accountId).getSingleOrNull();

  Future<void> save({
    required String accountId,
    required String json,
    required DateTime fetchedAt,
  }) => _db
      .into(_db.dashboardSnapshots)
      .insertOnConflictUpdate(
        DashboardSnapshotsCompanion.insert(
          accountId: accountId,
          json: json,
          fetchedAt: fetchedAt,
        ),
      );
}
