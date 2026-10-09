import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_sticker.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/repositories/sticker_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/save_image_as_sticker.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_sticker.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Chats extends Mock implements ChatRepository {}

class _Stickers extends Mock implements StickerRepository {}

void main() {
  late _Chats chats;
  late _Stickers stickers;
  final png = Uint8List.fromList([1, 2, 3]);
  const sticker = ChatSticker(
    id: 'assets/stickers/WorkNexus/ok.png',
    pack: 'WorkNexus',
    name: 'ok.png',
    location: 'assets/stickers/WorkNexus/ok.png',
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const MessageContent.text(''));
  });

  setUp(() {
    chats = _Chats();
    stickers = _Stickers();
  });

  test('a sticker is sent as an image file named after it', () async {
    when(() => stickers.bytes(sticker)).thenAnswer((_) async => Ok(png));
    when(
      () => chats.sendFile(
        any(),
        any(),
        name: any(named: 'name'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await SendSticker(chats, stickers)(
      accountId: 'acc',
      chatGid: 'g1',
      sticker: sticker,
    );

    expect(result, isA<Ok<void>>());
    verify(() => chats.sendFile('acc', 'g1', name: 'ok.png', bytes: png));
  });

  test('an unreadable sticker is not sent', () async {
    when(() => stickers.bytes(sticker))
        .thenAnswer((_) async => const Err(StorageFailure('gone')));

    final result = await SendSticker(chats, stickers)(
      accountId: 'acc',
      chatGid: 'g1',
      sticker: sticker,
    );

    expect(result, isA<Err<void>>());
    verifyNever(
      () => chats.sendFile(
        any(),
        any(),
        name: any(named: 'name'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('a large emoji goes out as its shortname', () async {
    when(() => chats.sendEmoji(any(), any(), any()))
        .thenAnswer((_) async => const Ok(null));

    await SendLargeEmoji(chats)(accountId: 'acc', chatGid: 'g1', emoji: '👍');

    verify(() => chats.sendEmoji('acc', 'g1', ':thumbsup:'));
  });

  test('only images can be saved as stickers', () async {
    final result = await SaveImageAsSticker(chats, stickers)(
      'acc',
      const MessageContent.text('hi'),
    );

    expect(result, isA<Err<ChatSticker>>());
  });

  test('an image is saved from its original bytes', () async {
    const image = MessageContent.image(
      fileId: 7,
      name: 'cat.png',
      size: 3,
      time: 1,
    );
    when(() => chats.loadAttachment('acc', image))
        .thenAnswer((_) async => Ok(png));
    when(() => stickers.add(any(), name: any(named: 'name')))
        .thenAnswer((_) async => const Ok(sticker));

    final result = await SaveImageAsSticker(chats, stickers)('acc', image);

    expect(result, const Ok(sticker));
    verify(() => stickers.add(png, name: 'cat.png'));
  });
}
