import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/message_content.dart';

part 'chat_message.freezed.dart';

enum SendState { sent, pending, failed }

/// One message in a conversation. [gid] is the client-generated id; [serverId]
/// is assigned by xxd once the message is stored (null while pending).
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String accountId,
    required String gid,
    required String chatGid,
    required int senderId,
    required DateTime sentAt,
    required MessageContent content,
    required bool isMine,
    @Default(SendState.sent) SendState sendState,
    int? serverId,
    @Default(false) bool deleted,
  }) = _ChatMessage;
}
