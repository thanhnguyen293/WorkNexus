import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';

Future<Set<String>> _tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return {for (final r in rows) r.read<String>('name')};
}

/// A current-schema DB file, changed by [strip] and marked [version] — the
/// shape a build from a parallel branch may have left behind.
Future<File> _seed(int version, void Function(Database raw) strip) async {
  final dir = await Directory.systemTemp.createTemp('wn_mini_app_mig');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/worknexus.db');
  final seed = AppDatabase(NativeDatabase(file));
  await seed.customStatement('SELECT 1');
  await seed.close();
  final raw = sqlite3.open(file.path);
  strip(raw);
  raw.execute('PRAGMA user_version = $version;');
  raw.close();
  return file;
}

void main() {
  test('a v54 DB without mini_app_permissions gets the table', () async {
    final file = await _seed(54, (raw) {
      raw.execute('DROP TABLE mini_app_permissions');
    });

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await _tableNames(db), contains('mini_app_permissions'));
    // And it is usable, not only present.
    await db.customSelect('SELECT * FROM mini_app_permissions').get();
  });

  test('a DB already at the current version gets a missing table', () async {
    final file = await _seed(55, (raw) {
      raw.execute('DROP TABLE mini_app_permissions');
    });

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await _tableNames(db), contains('mini_app_permissions'));
  });

  test('a v54 DB without mini_apps gets the table', () async {
    final file = await _seed(54, (raw) {
      raw.execute('DROP TABLE mini_apps');
    });

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await _tableNames(db), contains('mini_apps'));
    await db.select(db.miniApps).get();
  });

  test('an old DB that already has the mini-app tables still opens', () async {
    final file = await _seed(49, (_) {});

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(
      await _tableNames(db),
      containsAll(['mini_apps', 'mini_app_permissions']),
    );
  });
}
