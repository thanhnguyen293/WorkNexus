import 'dart:async';

import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../domain/repositories/sync_status_repository.dart';
import '../../domain/value_objects/account_sync_status.dart';

/// Implements [SyncStatusRepository] by keeping an active in-memory stream per
/// account and persisting `lastSyncedAt` in SQLite under `sync.last_synced_at.<id>`.
class SettingsSyncStatusRepository implements SyncStatusRepository {
  SettingsSyncStatusRepository(this._db);

  final AppDatabase _db;
  final Map<String, StreamController<AccountSyncStatus>> _controllers = {};
  final Map<String, AccountSyncStatus> _lastStatuses = {};
  bool _tableEnsured = false;

  Future<void> _ensureTable() async {
    if (_tableEnsured) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS app_settings_kv (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    _tableEnsured = true;
  }

  String _keyFor(String accountId) => 'sync.last_synced_at.$accountId';

  @override
  Stream<AccountSyncStatus> watch(String accountId) {
    var controller = _controllers[accountId];
    if (controller == null) {
      controller = StreamController<AccountSyncStatus>.broadcast();
      _controllers[accountId] = controller;
    }

    // Schedule initial emission
    unawaited(() async {
      final initial = await getStatus(accountId);
      if (!controller!.isClosed) {
        controller.add(initial);
      }
    }());

    return controller.stream;
  }

  @override
  Future<AccountSyncStatus> getStatus(String accountId) async {
    final cached = _lastStatuses[accountId];
    if (cached != null) return cached;

    try {
      await _ensureTable();
      final rows = await _db
          .customSelect(
            'SELECT value FROM app_settings_kv WHERE key = ?',
            variables: [Variable<String>(_keyFor(accountId))],
          )
          .get();

      if (rows.isNotEmpty) {
        final millis = int.tryParse(rows.first.read<String>('value'));
        if (millis != null) {
          final status = AccountSyncStatus.idle(
            lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(millis),
          );
          _lastStatuses[accountId] = status;
          return status;
        }
      }
    } catch (_) {
      // Fallback on read error
    }

    const defaultStatus = AccountSyncStatus.idle();
    _lastStatuses[accountId] = defaultStatus;
    return defaultStatus;
  }

  @override
  void report(String accountId, AccountSyncStatus status) {
    _lastStatuses[accountId] = status;
    final controller = _controllers[accountId];
    if (controller != null && !controller.isClosed) {
      controller.add(status);
    }

    if (status case SyncIdle(:final lastSyncedAt?)) {
      unawaited(() async {
        try {
          await _ensureTable();
          final now = DateTime.now().millisecondsSinceEpoch;
          await _db.customStatement(
            '''
            INSERT INTO app_settings_kv (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
            ''',
            [
              _keyFor(accountId),
              lastSyncedAt.millisecondsSinceEpoch.toString(),
              now,
            ],
          );
        } catch (_) {}
      }());
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}
