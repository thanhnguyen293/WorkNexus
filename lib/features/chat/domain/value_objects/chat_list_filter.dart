import '../entities/chat_conversation.dart';
import 'chat_list_tab.dart';

/// What the chat list shows, beyond the search text: a tab's slice, only
/// chats with unread messages, and only chats under the picked categories
/// (none picked: any).
final class ChatListFilter {
  const ChatListFilter({
    this.tab = ChatListTab.all,
    this.unreadOnly = false,
    this.categories = const {},
  });

  final ChatListTab tab;
  final bool unreadOnly;
  final Set<String> categories;

  /// Whether the "Categorize" filter narrows the list at all.
  bool get isNarrowed => unreadOnly || categories.isNotEmpty;

  bool matches(ChatConversation chat) =>
      !chat.hidden &&
      !chat.archived &&
      tab.matches(chat) &&
      (!unreadOnly || chat.unreadCount > 0) &&
      (categories.isEmpty || categories.contains(chat.category));
}
