import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';

final _day = DateTime(2026, 10, 10);

RecordedMessage _m(int index, {bool fromSelf = false, int? serverId}) => (
  serverId: serverId ?? 1000 + index,
  index: index,
  sentAt: _day.add(Duration(minutes: index)),
  fromSelf: fromSelf,
);

void main() {
  late AppDatabase db;
  late ChatLocalDatasource local;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    local = ChatLocalDatasource(db);
    await local.upsertConversations([
      const ChatConversationsCompanion(
        accountId: Value('acc'),
        gid: Value('g1'),
        type: Value('group'),
        name: Value('Team'),
        lastMessageId: Value(1003),
        lastMessageIndex: Value(3),
        lastReadIndex: Value(2),
      ),
    ]);
  });
  tearDown(() => db.close());

  Future<ChatConversationRow> chat() async =>
      (await local.conversation('acc', 'g1'))!;

  test('a page moves the chat to its newest message in one write', () async {
    await local.recordMessages('acc', 'g1', [_m(4), _m(5), _m(6)]);
    final row = await chat();
    expect(row.lastMessageId, 1006);
    expect(row.lastMessageIndex, 6);
    expect(row.lastActiveAt, _day.add(const Duration(minutes: 6)));
    expect(row.lastReadIndex, 2, reason: 'nothing of ours: still unread');
  });

  test('our own message marks the chat read up to there', () async {
    await local.recordMessages('acc', 'g1', [
      _m(4),
      _m(5, fromSelf: true),
      _m(6),
    ]);
    final row = await chat();
    expect(row.lastReadIndex, 5);
    expect(row.lastMessageIndex, 6);
  });

  test('a page already recorded leaves the chat untouched', () async {
    final before = await chat();
    var emissions = 0;
    final sub = local.watchConversations('acc').listen((_) => emissions++);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    final seen = emissions;

    await local.recordMessages('acc', 'g1', [_m(2), _m(3)]);
    await pumpEventQueue();

    expect(await chat(), before);
    expect(emissions, seen, reason: 'no write, so the list does not re-emit');
  });

  test('an older server id never moves the chat back', () async {
    await local.recordMessages('acc', 'g1', [_m(1, serverId: 900)]);
    final row = await chat();
    expect(row.lastMessageId, 1003);
    expect(row.lastActiveAt, isNull);
  });
}
