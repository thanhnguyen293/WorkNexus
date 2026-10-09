import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../../domain/usecases/save_image_as_sticker.dart';
import '../../domain/usecases/send_sticker.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_providers.dart';

final stickerRepositoryProvider = Provider<StickerRepository>(
  (ref) => getIt<StickerRepository>(),
);

/// Every sticker: bundled sets, then the user's own.
final chatStickersProvider =
    FutureProvider.autoDispose<Result<List<ChatSticker>>>(
      (ref) => ref.watch(stickerRepositoryProvider).stickers(),
    );

final stickerControllerProvider = Provider<StickerController>((ref) {
  final chats = ref.watch(chatRepositoryProvider);
  final stickers = ref.watch(stickerRepositoryProvider);
  return StickerController(
    stickers,
    sendSticker: SendSticker(chats, stickers),
    sendLargeEmoji: SendLargeEmoji(chats),
    saveImage: SaveImageAsSticker(chats, stickers),
    onChanged: () => ref.invalidate(chatStickersProvider),
  );
});

/// Sending stickers and large emoji, and keeping the user's own stickers.
class StickerController {
  StickerController(
    this._stickers, {
    required this._sendSticker,
    required this._sendLargeEmoji,
    required this._saveImage,
    required this._onChanged,
  });

  final StickerRepository _stickers;
  final SendSticker _sendSticker;
  final SendLargeEmoji _sendLargeEmoji;
  final SaveImageAsSticker _saveImage;
  final void Function() _onChanged;

  Future<Result<void>> send(ChatThreadKey chat, ChatSticker sticker) =>
      _sendSticker(
        accountId: chat.accountId,
        chatGid: chat.chatGid,
        sticker: sticker,
      );

  Future<Result<void>> sendEmoji(ChatThreadKey chat, String emoji) =>
      _sendLargeEmoji(
        accountId: chat.accountId,
        chatGid: chat.chatGid,
        emoji: emoji,
      );

  /// Keeps a chat image (its original) as one of the user's stickers.
  Future<Result<void>> saveImage(String accountId, MessageContent image) =>
      _changed(_saveImage(accountId, image));

  Future<Result<void>> add(Uint8List bytes, String name) =>
      _changed(_stickers.add(bytes, name: name));

  Future<Result<void>> remove(ChatSticker sticker) =>
      _changed(_stickers.remove(sticker));

  Future<Result<void>> _changed<T>(Future<Result<T>> action) async {
    final result = await action;
    if (result is Ok) _onChanged();
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
