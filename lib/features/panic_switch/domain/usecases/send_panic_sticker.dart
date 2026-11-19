import '../../../../core/error/result.dart';
import '../repositories/panic_chat_gateway.dart';
import '../repositories/panic_sticker_source.dart';
import '../value_objects/panic_trigger.dart';

/// Sends [trigger]'s sticker into [chatGid], under the reserved file name
/// receivers recognise it by.
class SendPanicSticker {
  const SendPanicSticker(this._chats, this._sticker);

  final PanicChatGateway _chats;
  final PanicStickerSource _sticker;

  Future<Result<void>> call({
    required PanicTrigger trigger,
    required String accountId,
    required String chatGid,
  }) async => switch (await _sticker.bytes()) {
    Ok(:final value) => _chats.sendFile(
      accountId,
      chatGid,
      name: trigger.stickerFileName,
      bytes: value,
      mimeType: 'image/png',
    ),
    Err(:final failure) => Err(failure),
  };
}
