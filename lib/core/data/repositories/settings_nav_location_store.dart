import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../navigation/app_nav_state.dart';
import '../../settings/nav_location_store.dart';

/// Drift/SQLite-backed implementation of [NavLocationStore] that stores
/// versioned JSON under the `nav.last_location.v1` key with a 500ms debounce.
class SettingsNavLocationStore implements NavLocationStore {
  SettingsNavLocationStore(this._db);

  final AppDatabase _db;
  Timer? _debounceTimer;
  NavLocationPayload? _pendingPayload;
  bool _tableEnsured = false;

  static const String _kStorageKey = 'nav.last_location.v1';

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

  @override
  Future<NavLocationPayload?> load() async {
    try {
      await _ensureTable();
      final rows = await _db
          .customSelect(
            'SELECT value FROM app_settings_kv WHERE key = ?',
            variables: [const Variable<String>(_kStorageKey)],
          )
          .get();

      if (rows.isEmpty) return null;
      final raw = rows.first.read<String>('value');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const NavLocationPayload();
      return NavLocationPayload.fromJson(decoded);
    } catch (_) {
      return const NavLocationPayload();
    }
  }

  @override
  void save(NavLocationPayload payload) {
    _pendingPayload = payload;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(flush());
    });
  }

  @override
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final payload = _pendingPayload;
    if (payload == null) return;
    _pendingPayload = null;

    try {
      await _ensureTable();
      final encoded = jsonEncode(payload.toJson());
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        '''
        INSERT INTO app_settings_kv (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;
        ''',
        [
          payload.version == NavLocationPayload.kNavLocationVersion
              ? _kStorageKey
              : _kStorageKey,
          encoded,
          now,
        ],
      );
    } catch (_) {
      // Invariant: silent failure on disk write does not crash app
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingPayload = null;
  }
}
