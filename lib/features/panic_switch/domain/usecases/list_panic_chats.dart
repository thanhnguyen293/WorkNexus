import '../../../chat/domain/entities/chat_conversation.dart';
import '../../../chat/domain/entities/chat_user.dart';
import '../../../chat/domain/usecases/resolve_chat_title.dart';

/// A chat the sticker can go to, with the title to show for it.
typedef PanicChat = ({ChatConversation chat, String title});

/// The chats the sticker can go to — groups and one-to-one chats, by title —
/// after the user's own chat ("My Cloud", shown as [selfTitle]), which is for
/// trying the switch alone.
class ListPanicChats {
  const ListPanicChats();

  List<PanicChat> call(
    List<ChatConversation> conversations,
    Map<int, ChatUser> usersById, {
    required String selfTitle,
  }) {
    final chats = <PanicChat>[];
    PanicChat? self;
    for (final c in conversations) {
      if (c.isMyCloud) {
        self ??= (chat: c, title: selfTitle);
        continue;
      }
      final kind = c.type == ChatType.group || c.type == ChatType.one2one;
      if (!kind || c.hidden) continue;
      final title = const ResolveChatTitle()(c, usersById);
      if (title != null) chats.add((chat: c, title: title));
    }
    chats.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return [?self, ...chats];
  }
}
