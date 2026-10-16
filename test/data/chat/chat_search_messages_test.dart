import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';

ChatMessagesCompanion _row(int i, String content, {String type = 'plain'}) =>
    ChatMessagesCompanion(
      accountId: const Value('acc'),
      gid: Value('m$i'),
      cgid: const Value('g1'),
      serverId: Value(1000 + i),
      messageIndex: Value(i),
      senderId: const Value(31),
      sentAt: Value(DateTime(2026, 10, 10).add(Duration(minutes: i))),
      contentType: Value(type),
      content: Value(content),
    );

void main() {
  late AppDatabase db;
  late ChatLocalDatasource local;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    local = ChatLocalDatasource(db);
    await local.upsertMessages([
      _row(1, 'rename snake_case vars'),
      _row(2, 'rename snakeXcase vars'),
      _row(3, 'coverage is 100% now'),
      _row(4, 'coverage is 1000 now'),
      _row(5, '{"id":7,"name":"shot.png","size":12}', type: 'image'),
      _row(6, 'the png export works'),
    ], link: MessageLink.linked);
  });
  tearDown(() => db.close());

  Future<List<String>> search(String query) async => [
    for (final r in await local.searchMessages('acc', query: query)) r.gid,
  ];

  test('wildcard characters in the query match literally', () async {
    expect(await search('snake_case'), ['m1']);
    expect(await search('100%'), ['m3']);
  });

  test('only text messages are searched, not file payloads', () async {
    expect(await search('png'), ['m6']);
    expect(await search('size'), isEmpty);
  });
}
