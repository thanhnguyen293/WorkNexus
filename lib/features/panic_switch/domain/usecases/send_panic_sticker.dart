import '../../../../core/error/result.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../panic_switch_constants.dart';
import '../repositories/panic_sticker_source.dart';

/// Sends the "Thầy vô" sticker into [chatGid], under the reserved file name
/// receivers recognise it by.
class SendPanicSticker {
  const SendPanicSticker(this._chats, this._sticker);

  final ChatRepository _chats;
  final PanicStickerSource _sticker;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
  }) async => switch (await _sticker.bytes()) {
    Ok(:final value) => _chats.sendFile(
      accountId,
      chatGid,
      name: PanicSwitchConstants.stickerFileName,
      bytes: value,
      mimeType: 'image/png',
    ),
    Err(:final failure) => Err(failure),
  };
}
