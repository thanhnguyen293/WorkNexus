import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';

/// Regression: a dev DB can be left half-migrated to schema v14 — the
/// `translation_lang` column added, but `user_version` still 13 (e.g. an app
/// killed mid-open). The v14 migration must be idempotent and not crash with
/// "duplicate column name: translation_lang".
void main() {
  test('v14 migration skips translation_lang when it already exists', () async {
    final dir = await Directory.systemTemp.createTemp('wn_mig_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/worknexus.db');

    // Hand-build a v13 DB that *already* carries the v14 column.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE settings (
        id INTEGER NOT NULL DEFAULT 0 PRIMARY KEY,
        variant TEXT NOT NULL DEFAULT 'light',
        surface TEXT NOT NULL DEFAULT 'outline',
        density TEXT NOT NULL DEFAULT 'comfortable',
        detail_layout TEXT NOT NULL DEFAULT 'twoPane',
        date_format TEXT NOT NULL DEFAULT 'iso',
        company_tint INTEGER NOT NULL DEFAULT 0,
        locale_code TEXT NOT NULL DEFAULT 'en',
        translation_lang TEXT NOT NULL DEFAULT 'vi',
        font_family TEXT NOT NULL DEFAULT 'Space Grotesk',
        component_radius REAL NOT NULL DEFAULT 8.0,
        accent_color_value INTEGER,
        pinned_projects_json TEXT NOT NULL DEFAULT '[]',
        pinned_executions_json TEXT NOT NULL DEFAULT '[]',
        sidebar_width REAL NOT NULL DEFAULT 290.0
      );
    ''');
    raw.execute("INSERT INTO settings (id) VALUES (0);");
    raw.execute('PRAGMA user_version = 13;');
    raw.dispose();

    // Opening runs the migration; the guard must skip the duplicate add.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final row = await db.select(db.settings).getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.translationLang, 'vi');

    // Migration completed and bumped the version to current.
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });
}
