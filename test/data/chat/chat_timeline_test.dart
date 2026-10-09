import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';

/// A stored message of chat `g1` with per-chat [index] and server id
/// `1000 + index`, sent [index] minutes into the day.
ChatMessagesCompanion _row(int index) => ChatMessagesCompanion(
  accountId: const Value('acc'),
  gid: Value('m$index'),
  cgid: const Value('g1'),
  serverId: Value(1000 + index),
  messageIndex: Value(index),
  senderId: const Value(31),
  sentAt: Value(DateTime(2026, 10, 10).add(Duration(minutes: index))),
  contentType: const Value('plain'),
  content: Value('message $index'),
);

List<ChatMessagesCompanion> _rows(int from, int to) => [
  for (var i = from; i <= to; i++) _row(i),
];

void main() {
  late AppDatabase db;
  late ChatLocalDatasource local;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = ChatLocalDatasource(db);
  });
  tearDown(() => db.close());

  Future<List<int?>> timeline({int limit = 100}) async => [
    for (final r in await local.watchMessages('acc', 'g1', limit: limit).first)
      r.messageIndex,
  ];

  test('a reply parent fetched on its own stays out of the timeline', () async {
    // The newest page (96–100) and the parent of #100's reply (#1).
    await local.upsertMessages(_rows(96, 100), link: MessageLink.linked);
    await local.upsertMessages([_row(1)], link: MessageLink.detached);

    expect(await timeline(), [96, 97, 98, 99, 100]);
    // Nothing stored continues the timeline: older pages come from the
    // server, not from the lone parent.
    expect(await local.countOlder('acc', 'g1', _row(96).sentAt.value), 0);
  });

  test('a page reaching a detached message joins it to the timeline', () async {
    await local.upsertMessages([_row(5)], link: MessageLink.detached);
    await local.upsertMessages(_rows(4, 6), link: MessageLink.linked);

    expect(await timeline(), [4, 5, 6]);
  });

  test(
    'fetching on its own never takes a message out of the timeline',
    () async {
      await local.upsertMessages(_rows(1, 3), link: MessageLink.linked);
      await local.upsertMessages([_row(2)], link: MessageLink.detached);

      expect(await timeline(), [1, 2, 3]);
    },
  );

  test(
    'a newest page that does not reach the stored history cuts it off',
    () async {
      await local.upsertMessages(_rows(1, 3), link: MessageLink.linked);
      // The chat moved on while away: 4–7 were never fetched.
      await local.upsertMessages(_rows(8, 10), link: MessageLink.linked);
      await local.timeline.detachIfCutOffBelow('acc', 'g1', 8);

      expect(await timeline(), [8, 9, 10]);
    },
  );

  test('a newest page that continues the stored history keeps it', () async {
    await local.upsertMessages(_rows(1, 3), link: MessageLink.linked);
    await local.upsertMessages(_rows(4, 6), link: MessageLink.linked);
    await local.timeline.detachIfCutOffBelow('acc', 'g1', 4);

    expect(await timeline(), [1, 2, 3, 4, 5, 6]);
  });

  test('a jump window joins the timeline once it reaches it', () async {
    await local.upsertMessages(_rows(1, 3), link: MessageLink.detached);
    await local.upsertMessages(_rows(4, 6), link: MessageLink.linked);

    final count = await local.timeline.joinWindow('acc', 'g1', from: 1, to: 3);

    expect(count, 6);
    expect(await timeline(), [1, 2, 3, 4, 5, 6]);
  });

  test('a jump window short of the timeline stays apart', () async {
    await local.upsertMessages(_rows(1, 3), link: MessageLink.detached);
    await local.upsertMessages(_rows(6, 8), link: MessageLink.linked);

    expect(
      await local.timeline.joinWindow('acc', 'g1', from: 1, to: 3),
      isNull,
    );
    expect(await timeline(), [6, 7, 8]);
  });

  test('a jump window shows its stretch, timeline or not', () async {
    await local.upsertMessages(_rows(1, 3), link: MessageLink.detached);
    await local.upsertMessages(_rows(8, 10), link: MessageLink.linked);

    final window = await local.timeline
        .watchMessagesInRange('acc', 'g1', from: 2, to: 9)
        .first;

    expect([for (final r in window) r.messageIndex], [2, 3, 8, 9]);
  });

  test('upgrading to v40 detaches stored history past its first gap', () async {
    final dir = await Directory.systemTemp.createTemp('wn_timeline_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/worknexus.db');

    // A v39 DB: today's schema without the `detached` column, holding the
    // newest page (8–10) and a lone reply parent (#1) stored before it.
    final current = AppDatabase(NativeDatabase(file));
    final old = ChatLocalDatasource(current);
    await old.upsertMessages([..._rows(8, 10), _row(1)]);
    await current.close();
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE chat_messages DROP COLUMN detached;');
    raw.execute('PRAGMA user_version = 39;');
    raw.dispose();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final rows = await ChatLocalDatasource(
      upgraded,
    ).watchMessages('acc', 'g1', limit: 100).first;

    expect([for (final r in rows) r.messageIndex], [8, 9, 10]);
  });
}
