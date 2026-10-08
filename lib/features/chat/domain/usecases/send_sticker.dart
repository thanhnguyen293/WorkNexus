import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_sticker.dart';
import '../repositories/chat_repository.dart';
import '../repositories/sticker_repository.dart';
import 'encode_emoji.dart';

/// Sends a sticker image as an image message.
class SendSticker {
  const SendSticker(this._chats, this._stickers);

  final ChatRepository _chats;
  final StickerRepository _stickers;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required ChatSticker sticker,
  }) async => switch (await _stickers.bytes(sticker)) {
    Ok(:final value) => _chats.sendFile(
      accountId,
      chatGid,
      name: sticker.name,
      bytes: value,
    ),
    Err(:final failure) => Err(failure),
  };
}

/// Sends one emoji shown large, without a bubble — the official client's
/// emoticon message, which it also renders.
class SendLargeEmoji {
  const SendLargeEmoji(this._chats);

  final ChatRepository _chats;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required String emoji,
  }) {
    final code = const EncodeEmoji()(emoji.trim());
    if (code.isEmpty) {
      return Future.value(const Err(UnexpectedFailure('No emoji to send')));
    }
    return _chats.sendEmoji(accountId, chatGid, code);
  }
}
