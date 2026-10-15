import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';

/// The indexes v54 adds for the columns the detail panel, the chat list and
/// the history pager filter on.
const _indexes = [
  'tickets_by_account',
  'comments_by_ticket',
  'activities_by_ticket',
  'chat_messages_by_server_id',
  'chat_messages_by_index',
];

Future<Set<String>> _indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return {for (final r in rows) r.read<String>('name')};
}

void main() {
  test('a fresh database has the lookup indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _indexNames(db), containsAll(_indexes));
  });

  test('v54 adds the lookup indexes to a database that lacks them', () async {
    final dir = await Directory.systemTemp.createTemp('wn_index_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/worknexus.db');

    // a current-schema DB, stripped of the new indexes and marked v53.
    final seed = AppDatabase(NativeDatabase(file));
    await seed.customStatement('SELECT 1');
    await seed.close();
    final raw = sqlite3.open(file.path);
    for (final name in _indexes) {
      raw.execute('DROP INDEX $name');
    }
    raw.execute('PRAGMA user_version = 53;');
    raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await _indexNames(db), containsAll(_indexes));
  });
}
