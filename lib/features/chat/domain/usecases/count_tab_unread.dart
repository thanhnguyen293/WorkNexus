import '../entities/chat_conversation.dart';
import '../value_objects/chat_list_tab.dart';

/// Unread messages in the chats a tab of the chat list shows: the ones the
/// list itself shows (not hidden or archived) that fall under the tab.
class CountTabUnread {
  const CountTabUnread();

  int call(Iterable<ChatConversation> chats, ChatListTab tab) => chats
      .where((c) => !c.hidden && !c.archived && tab.matches(c))
      .fold(0, (total, c) => total + c.unreadCount);
}
