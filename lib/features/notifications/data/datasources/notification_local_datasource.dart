import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';

/// Drift access to the stored ZenTao notifications ([ZenTaoNotifications]).
class NotificationLocalDatasource {
  const NotificationLocalDatasource(this._db);

  final AppDatabase _db;

  Stream<List<ZenTaoNotificationRow>> watchAll() =>
      (_db.select(_db.zenTaoNotifications)..orderBy([
            (n) =>
                OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
          ]))
          .watch();

  /// Replaces every row of [accountId] with [rows], atomically.
  Future<void> replaceAccount(
    String accountId,
    List<ZenTaoNotificationsCompanion> rows,
  ) => _db.transaction(() async {
    await (_db.delete(
      _db.zenTaoNotifications,
    )..where((n) => n.accountId.equals(accountId))).go();
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.zenTaoNotifications, rows),
    );
  });

  /// Sets [read] on one notification, or with a null [id] on all of
  /// [accountId]'s.
  Future<void> setRead(String accountId, {String? id, required bool read}) =>
      (_db.update(_db.zenTaoNotifications)..where(
            (n) =>
                n.accountId.equals(accountId) &
                (id == null ? const Constant(true) : n.id.equals(id)),
          ))
          .write(ZenTaoNotificationsCompanion(read: Value(read)));

  /// Deletes one notification, or with [readOnly] all read ones of
  /// [accountId].
  Future<void> delete(String accountId, {String? id, bool readOnly = false}) =>
      (_db.delete(_db.zenTaoNotifications)..where(
            (n) =>
                n.accountId.equals(accountId) &
                (id == null ? const Constant(true) : n.id.equals(id)) &
                (readOnly ? n.read.equals(true) : const Constant(true)),
          ))
          .go();
}
