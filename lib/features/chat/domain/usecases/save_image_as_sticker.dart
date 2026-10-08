import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_sticker.dart';
import '../repositories/chat_repository.dart';
import '../repositories/sticker_repository.dart';
import '../value_objects/message_content.dart';

/// Keeps an image from a chat (the original, not the preview) as one of the
/// user's own stickers.
class SaveImageAsSticker {
  const SaveImageAsSticker(this._chats, this._stickers);

  final ChatRepository _chats;
  final StickerRepository _stickers;

  Future<Result<ChatSticker>> call(
    String accountId,
    MessageContent content,
  ) async {
    if (content is! ImageContent) {
      return const Err(UnexpectedFailure('Only images can become stickers'));
    }
    return switch (await _chats.loadAttachment(accountId, content)) {
      Ok(:final value) => _stickers.add(
        value,
        name: content.name.isEmpty ? 'sticker.png' : content.name,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
