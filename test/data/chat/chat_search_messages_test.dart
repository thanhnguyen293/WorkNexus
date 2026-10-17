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

  test('ignores case and Vietnamese diacritics', () async {
    await local.upsertMessages([
      _row(7, 'Đã Gửi Báo Cáo'),
    ], link: MessageLink.linked);
    expect(await search('da gui bao cao'), ['m7']);
    expect(await search('ĐÃ GỬI'), ['m7']);
  });

  test(
    'matches a mention by name and a Markdown message by its text',
    () async {
      await local.upsertMessages([
        _row(7, 'hỏi [@Thành](@#40) giúp'),
        _row(8, '**deploy** xong', type: 'text'),
      ], link: MessageLink.linked);
      expect(await search('@thanh giup'), ['m7']);
      expect(await search('@#40'), isEmpty);
      expect(await search('deploy xong'), ['m8']);
    },
  );

  test('a pending upload replaced by its file leaves the search', () async {
    await local.upsertMessages([
      _row(7, 'uploading report'),
    ], link: MessageLink.linked);
    await local.setContent(
      'acc',
      'm7',
      contentType: 'file',
      content: '{"name":"report.pdf"}',
    );
    expect(await search('report'), isEmpty);
  });

  test('without a limit every match comes back, newest first', () async {
    await local.upsertMessages([
      for (var i = 10; i < 160; i++) _row(i, 'release $i'),
    ], link: MessageLink.linked);
    final all = await search('release');
    expect(all, hasLength(150));
    expect(all.first, 'm159');
    final page = await local.searchMessages('acc', query: 'release', limit: 5);
    expect(page.map((r) => r.gid), ['m159', 'm158', 'm157', 'm156', 'm155']);
  });

  test('rows stored before search_text existed are filled in', () async {
    // As a database upgraded from schema 55 has them: no search text.
    await db.customStatement('UPDATE chat_messages SET search_text = NULL');
    expect(await search('snake_case'), ['m1']);
    final m6 = await local.message('acc', 'm6');
    expect(m6?.searchText, 'the png export works');
    final m5 = await local.message('acc', 'm5');
    expect(m5?.searchText, isNull);
  });
}
