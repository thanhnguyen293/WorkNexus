import 'package:freezed_annotation/freezed_annotation.dart';

part 'panic_incoming_message.freezed.dart';

/// A message that just arrived in one of the account's chats; [imageName] is
/// the file name when it is an image, which is how a sticker is recognised.
@freezed
abstract class PanicIncomingMessage with _$PanicIncomingMessage {
  const factory PanicIncomingMessage({
    required String accountId,
    required String chatGid,
    required int senderId,
    required DateTime sentAt,
    required bool isMine,
    @Default(false) bool deleted,
    String? imageName,
  }) = _PanicIncomingMessage;
}
