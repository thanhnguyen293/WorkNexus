import '../entities/chat_conversation.dart';

/// Unread messages the app icon badge shows: those in chats the user still
/// follows — a hidden, archived or muted chat stays out of it, as it does
/// out of desktop notifications.
class CountBadgeUnread {
  const CountBadgeUnread();

  int call(Iterable<ChatConversation> chats) => chats
      .where((c) => !c.hidden && !c.archived && !c.muted)
      .fold(0, (total, c) => total + c.unreadCount);
}
