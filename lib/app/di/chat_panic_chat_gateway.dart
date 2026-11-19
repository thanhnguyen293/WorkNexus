import 'dart:typed_data';

import '../../core/error/result.dart';
import '../../features/chat/domain/entities/chat_conversation.dart';
import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/chat/domain/entities/chat_user.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/value_objects/message_content.dart';
import '../../features/panic_switch/domain/entities/panic_conversation.dart';
import '../../features/panic_switch/domain/entities/panic_incoming_message.dart';
import '../../features/panic_switch/domain/entities/panic_member.dart';
import '../../features/panic_switch/domain/repositories/panic_chat_gateway.dart';

/// Lets the panic switch read and send through chat without depending on the
/// chat feature: the composition root is the one place that knows both.
class ChatPanicChatGateway implements PanicChatGateway {
  const ChatPanicChatGateway(this._chats);

  final ChatRepository _chats;

  @override
  Stream<PanicIncomingMessage> watchIncoming() =>
      _chats.watchIncoming().map(_message);

  @override
  Stream<List<PanicConversation>> watchConversations(String accountId) => _chats
      .watchConversations(accountId)
      .map((chats) => [for (final c in chats) _conversation(c)]);

  @override
  Stream<List<PanicMember>> watchUsers(String accountId) => _chats
      .watchUsers(accountId)
      .map((users) => [for (final u in users) _member(u)]);

  @override
  Stream<int?> watchSelfUserId(String accountId) =>
      _chats.watchSelfUserId(accountId);

  @override
  Future<Result<List<int>>> members(String accountId, String chatGid) =>
      _chats.members(accountId, chatGid);

  @override
  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) => _chats.sendFile(
    accountId,
    chatGid,
    name: name,
    bytes: bytes,
    mimeType: mimeType,
  );

  static PanicIncomingMessage _message(ChatMessage m) => PanicIncomingMessage(
    accountId: m.accountId,
    chatGid: m.chatGid,
    senderId: m.senderId,
    sentAt: m.sentAt,
    isMine: m.isMine,
    deleted: m.deleted,
    imageName: switch (m.content) {
      ImageContent(:final name) => name,
      _ => null,
    },
  );

  static PanicConversation _conversation(ChatConversation c) =>
      PanicConversation(
        gid: c.gid,
        kind: switch (c.type) {
          ChatType.group => PanicChatKind.group,
          ChatType.one2one => PanicChatKind.direct,
          ChatType.bot ||
          ChatType.system ||
          ChatType.other => PanicChatKind.other,
        },
        name: c.name,
        peerUserId: c.peerUserId,
        isSelf: c.isMyCloud,
        hidden: c.hidden,
      );

  static PanicMember _member(ChatUser u) => PanicMember(
    userId: u.userId,
    account: u.account,
    realname: u.realname,
    avatarUrl: u.avatarUrl,
  );
}
