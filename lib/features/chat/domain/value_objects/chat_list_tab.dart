import '../entities/chat_conversation.dart';

/// The tabs above the chat list, each a slice of the conversations.
enum ChatListTab {
  all,
  direct,
  groups,
  bots;

  bool matches(ChatConversation chat) => switch (this) {
    all => true,
    direct => chat.type == ChatType.one2one,
    groups => chat.type == ChatType.group,
    bots => chat.type == ChatType.bot || chat.type == ChatType.system,
  };
}
