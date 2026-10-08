import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_file_cache.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:work_nexus/features/chat/data/repositories/chat_attachment_loader.dart';
import 'package:work_nexus/features/chat/data/repositories/chat_cache_manager.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';

import 'support/fake_xxd_server.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late ChatFileCache files;
  late ChatCacheManager cache;

  Future<void> message(String cgid, int fileId, String name) => db
      .into(db.chatMessages)
      .insert(
        ChatMessagesCompanion.insert(
          accountId: 'acc',
          gid: 'm$fileId',
          cgid: cgid,
          senderId: 31,
          sentAt: DateTime(2026),
          contentType: 'file',
          content: jsonEncode({
            'id': fileId,
            'name': name,
            'size': 10,
            'time': 1,
          }),
        ),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('chat_cache');
    files = ChatFileCache(root: () async => dir);
    final local = ChatLocalDatasource(db);
    cache = ChatCacheManager(
      local,
      files,
      ChatAttachmentLoader(FakeXxdHttp(serverInfoOk()), files),
      const ParseMessageContent(),
    );
    await db
        .into(db.chatAccounts)
        .insert(ChatAccountsCompanion.insert(accountId: 'acc'));
    await message('g1', 1, 'a.mp4');
    await message('g1', 2, 'b.pdf');
    await message('g2', 3, 'c.zip');
    await files.write('acc', '1_a.mp4', Uint8List(300));
    await files.write('acc', '1_a.mp4.thumb.png', Uint8List(20));
    await files.write('acc', '2_b.pdf', Uint8List(100));
    await files.write('acc', '3_c.zip', Uint8List(50));
    await files.write('acc', '9_orphan.bin', Uint8List(7));
  });

  tearDown(() async {
    await db.close();
    // Clearing everything removes the cache folder itself.
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('usage is split per chat, largest first; the rest is other', () async {
    final usage = (await cache.usage()).valueOrNull!;
    expect(usage.totalBytes, 477);
    expect(
      [for (final c in usage.chats) (c.chatGid, c.bytes)],
      [('g1', 420), ('g2', 50)],
    );
    expect(usage.otherBytes, 7);
  });

  test('clearing one chat keeps the others', () async {
    expect(await cache.clear(accountId: 'acc', chatGid: 'g1'), isA<Ok<void>>());
    final usage = (await cache.usage()).valueOrNull!;
    expect([for (final c in usage.chats) c.chatGid], ['g2']);
    expect(usage.totalBytes, 57);
  });

  test('clearing all empties the cache', () async {
    await cache.clear();
    expect((await cache.usage()).valueOrNull!.totalBytes, 0);
  });

  test('lowering the limit trims the least recently used files', () async {
    files.maxBytes = 200;
    await files.trim();
    expect(
      (await cache.usage()).valueOrNull!.totalBytes,
      lessThanOrEqualTo(180),
    );
  });
}
