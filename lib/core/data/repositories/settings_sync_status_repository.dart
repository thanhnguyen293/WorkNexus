import 'dart:async';

import '../../database/app_settings_kv_store.dart';
import '../../database/database.dart';
import '../../domain/repositories/sync_status_repository.dart';
import '../../domain/value_objects/account_sync_status.dart';

/// Implements [SyncStatusRepository] by keeping an active in-memory stream per
/// account and persisting `lastSyncedAt` in SQLite under `sync.last_synced_at.<id>`.
class SettingsSyncStatusRepository implements SyncStatusRepository {
  SettingsSyncStatusRepository(AppDatabase db) : _kv = AppSettingsKvStore(db);

  final AppSettingsKvStore _kv;
  final Map<String, StreamController<AccountSyncStatus>> _controllers = {};
  final Map<String, AccountSyncStatus> _lastStatuses = {};

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
      final stored = await _kv.read(_keyFor(accountId));
      if (stored != null) {
        final millis = int.tryParse(stored);
        if (millis != null) {
          // A status reported during the read is newer than the stored one.
          return _lastStatuses[accountId] ??= AccountSyncStatus.idle(
            lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(millis),
          );
        }
      }
    } catch (_) {
      // Fallback on read error
    }

    return _lastStatuses[accountId] ??= const AccountSyncStatus.idle();
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
          await _kv.write(
            _keyFor(accountId),
            lastSyncedAt.millisecondsSinceEpoch.toString(),
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
