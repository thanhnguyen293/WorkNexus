import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/panic_conversation.dart';
import '../entities/panic_incoming_message.dart';
import '../entities/panic_member.dart';

/// What the switch needs from chat: the account's chats and people, arriving
/// messages, and a way to send the sticker. The switch owns this port so it
/// does not depend on the chat feature; the composition root adapts chat to
/// it.
abstract interface class PanicChatGateway {
  /// Messages arriving in any account's chats, as they come.
  Stream<PanicIncomingMessage> watchIncoming();

  /// The account's chats.
  Stream<List<PanicConversation>> watchConversations(String accountId);

  /// The users the account knows.
  Stream<List<PanicMember>> watchUsers(String accountId);

  /// The account's own user id, once known.
  Stream<int?> watchSelfUserId(String accountId);

  /// The user ids of [chatGid]'s members.
  Future<Result<List<int>>> members(String accountId, String chatGid);

  /// Sends [bytes] into [chatGid] as a file named [name].
  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
  });
}
