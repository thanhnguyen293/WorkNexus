import '../entities/chat_conversation.dart';
import '../entities/chat_user.dart';

/// The display title of a conversation, or null when there is nothing better
/// than a generic label (the UI supplies a localized fallback).
///
/// One-to-one chats have no name on the server: they are titled after the
/// other member. Every other type uses its own name.
class ResolveChatTitle {
  const ResolveChatTitle();

  String? call(ChatConversation chat, Map<int, ChatUser> usersById) {
    if (chat.type == ChatType.one2one) {
      final peer = usersById[chat.peerUserId];
      if (peer == null) return null;
      return peer.realname.isNotEmpty ? peer.realname : peer.account;
    }
    final name = chat.name.trim();
    return name.isEmpty ? null : name;
  }
}
