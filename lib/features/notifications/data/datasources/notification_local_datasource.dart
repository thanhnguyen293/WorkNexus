import 'dart:convert';

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

  /// The stored rows of [accountId], newest first.
  Future<List<ZenTaoNotificationRow>> rowsOf(String accountId) =>
      (_db.select(_db.zenTaoNotifications)
            ..where((n) => n.accountId.equals(accountId))
            ..orderBy([
              (n) => OrderingTerm(
                expression: n.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  /// Realnames from stored ZenTao profiles, keyed by accountId.
  Stream<Map<String, String>> watchAccountRealnames() =>
      _db.select(_db.zenTaoProfiles).watch().map((rows) {
        final map = <String, String>{};
        for (final row in rows) {
          try {
            final json = jsonDecode(row.profileJson);
            final raw = json is Map ? json['profile'] : null;
            if (raw is Map) {
              final realname = raw['realname']?.toString().trim();
              if (realname != null && realname.isNotEmpty) {
                map[row.accountId] = realname;
              }
            }
          } catch (_) {}
        }
        return map;
      });

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
