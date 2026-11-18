import '../entities/chat_conversation.dart';

/// The categories the user files chats under, A–Z, with the unread messages
/// of the listed chats (not hidden or archived) in each.
class ListChatCategories {
  const ListChatCategories();

  Map<String, int> call(Iterable<ChatConversation> chats) {
    final unread = <String, int>{};
    for (final c in chats) {
      if (c.category.isEmpty || c.hidden || c.archived) continue;
      unread[c.category] = (unread[c.category] ?? 0) + c.unreadCount;
    }
    final names = unread.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final n in names) n: unread[n]!};
  }
}
