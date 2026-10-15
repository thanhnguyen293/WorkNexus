import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';

/// Regression: ZenTao bugs and tasks number independently, but their ticket
/// ids were `account:<number>`, so bug #6492 and task #6492 shared one row and
/// a bug notification could open the task. v44 types the stored ids.
void main() {
  test(
    'v44 adds the ZenTao type to ticket ids and what points at them',
    () async {
      final dir = await Directory.systemTemp.createTemp('wn_zt_id_mig');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/worknexus.db');

      // A current-schema DB holding v43-style rows, reopened as v43.
      final seed = AppDatabase(NativeDatabase(file));
      await seed.customStatement('SELECT 1');
      await seed.close();
      final raw = sqlite3.open(file.path);
      void ticket(String id, String provider, String? type, String key) =>
          raw.execute(
            'INSERT INTO tickets (id, account_id, project_id, provider_type, '
            'external_key, external_type, title, body, priority_level, '
            'status_norm, provider_status, source_hash) '
            "VALUES (?, 'zt', 'zt:p', ?, ?, ?, '', '', 2, 'todo', '', '')",
            [id, provider, key, type],
          );
      ticket('zt:6492', 'zentao', 'Bug', '6492');
      ticket('zt:7', 'zentao', 'Task', '7');
      ticket('zt:g:1', 'gitlab', 'MergeRequest', '1');
      raw.execute(
        'INSERT INTO comments (id, ticket_id, author_name, body, created_at) '
        "VALUES ('c1', 'zt:6492', 'a', 'b', 0), ('c2', 'zt:g:1', 'a', 'b', 0)",
      );
      raw.execute('PRAGMA user_version = 43;');
      raw.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final ids = (await db.select(db.tickets).get()).map((t) => t.id);
      expect(ids, unorderedEquals(['zt:bug:6492', 'zt:task:7', 'zt:g:1']));
      final comments = {
        for (final c in await db.select(db.comments).get()) c.id: c.ticketId,
      };
      expect(comments, {'c1': 'zt:bug:6492', 'c2': 'zt:g:1'});
    },
  );
}
