import '../entities/panic_conversation.dart';
import '../entities/panic_member.dart';

/// A chat the sticker can go to, with the title to show for it.
typedef PanicChat = ({PanicConversation chat, String title});

/// The chats the sticker can go to — groups and direct chats, by title —
/// after the user's own chat ("My Cloud", shown as [selfTitle]), which is for
/// trying the switch alone.
class ListPanicChats {
  const ListPanicChats();

  List<PanicChat> call(
    List<PanicConversation> conversations,
    Map<int, PanicMember> usersById, {
    required String selfTitle,
  }) {
    final chats = <PanicChat>[];
    PanicChat? self;
    for (final c in conversations) {
      if (c.isSelf) {
        self ??= (chat: c, title: selfTitle);
        continue;
      }
      if (c.kind == PanicChatKind.other || c.hidden) continue;
      final title = _title(c, usersById);
      if (title != null) chats.add((chat: c, title: title));
    }
    chats.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return [?self, ...chats];
  }

  /// Same rule as chat's own titles: a direct chat is named after its peer,
  /// any other after itself; null when there is nothing to show.
  static String? _title(PanicConversation c, Map<int, PanicMember> users) {
    if (c.kind == PanicChatKind.direct) return users[c.peerUserId]?.displayName;
    final name = c.name.trim();
    return name.isEmpty ? null : name;
  }
}
