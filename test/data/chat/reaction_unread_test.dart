import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:work_nexus/features/chat/data/repositories/chat_packet_ingestor.dart';

/// Someone's 👍 reply to message 1003, as xxd sends it.
const _emojiReply = <String, Object?>{
  'gid': 'r1',
  'cgid': 'g1',
  'id': 1004,
  'index': 4,
  'user': 9,
  'contentType': 'image',
  'content': '{"type":"emoji","content":":thumbsup:"}',
  'data': '{"replyTo":1003}',
};

void main() {
  late AppDatabase db;
  late ChatLocalDatasource local;
  late ChatPacketIngestor ingestor;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    local = ChatLocalDatasource(db);
    ingestor = ChatPacketIngestor(local);
    // Read up to its last message.
    await local.upsertConversations([
      const ChatConversationsCompanion(
        accountId: Value('acc'),
        gid: Value('g1'),
        type: Value('group'),
        name: Value('Team'),
        lastMessageId: Value(1003),
        lastMessageIndex: Value(3),
        lastReadIndex: Value(3),
      ),
    ]);
  });
  tearDown(() => db.close());

  Future<ChatConversationRow> chat() async =>
      (await local.conversation('acc', 'g1'))!;

  test('with reactions on, an emoji reply leaves a read chat read', () async {
    ingestor.reactions = true;
    await ingestor.storeMessages('acc', [_emojiReply], selfUserId: 40);
    final row = await chat();
    expect(row.lastMessageIndex, 4);
    expect(row.lastReadIndex, 4);
  });

  test('with reactions off (the default), an emoji reply is unread like any '
      'message', () async {
    await ingestor.storeMessages('acc', [_emojiReply], selfUserId: 40);
    final row = await chat();
    expect(row.lastMessageIndex, 4);
    expect(row.lastReadIndex, 3);
  });
}
