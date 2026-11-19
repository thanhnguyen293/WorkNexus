import 'package:drift/drift.dart';

import 'database.dart';

/// Small app-wide values kept by key in `app_settings_kv`, a table created on
/// first use rather than by a drift migration. The one owner of its schema.
class AppSettingsKvStore {
  AppSettingsKvStore(this._db);

  final AppDatabase _db;
  bool _tableEnsured = false;

  Future<String?> read(String key) async {
    await _ensureTable();
    final rows = await _db
        .customSelect(
          'SELECT value FROM app_settings_kv WHERE key = ?',
          variables: [Variable<String>(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  Future<void> write(String key, String value) async {
    await _ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO app_settings_kv (key, value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET
        value = excluded.value, updated_at = excluded.updated_at;
      ''',
      [key, value, DateTime.now().millisecondsSinceEpoch],
    );
  }

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
}
