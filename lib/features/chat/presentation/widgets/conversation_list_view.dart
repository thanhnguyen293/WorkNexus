import 'package:flutter/widgets.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import 'conversation_row.dart';
import 'list_row_widget_cache.dart';

/// A chat listed with the title it is shown (and searched) by.
typedef ListedChat = ({ChatConversation chat, String title});

/// The scrolling list of [chats]. A new message re-emits every chat of the
/// account; only the rows whose chat changed are rebuilt — the others keep
/// their widget (see [ListRowWidgetCache]). Each row watches its own
/// selection, so opening a chat redraws two rows, not the list.
class ConversationListView extends StatefulWidget {
  const ConversationListView({
    super.key,
    required this.accountId,
    required this.chats,
    required this.users,
    required this.compact,
  });

  final String accountId;
  final List<ListedChat> chats;
  final Map<int, ChatUser> users;
  final bool compact;

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  final _rows = ListRowWidgetCache();

  @override
  void didUpdateWidget(ConversationListView old) {
    super.didUpdateWidget(old);
    if (old.accountId != widget.accountId) _rows.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chats = widget.chats;
    _rows.retain({for (final e in chats) e.chat.gid});
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final (:chat, :title) = chats[i];
        return _rows.row(
          chat.gid,
          [chat, title, widget.users, widget.compact],
          () => ConversationRow(
            key: ValueKey(chat.gid),
            accountId: widget.accountId,
            chat: chat,
            title: title,
            users: widget.users,
            compact: widget.compact,
          ),
        );
      },
      // Rows keep their element (hover, privacy reveal) as chats reorder.
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final at = chats.indexWhere((e) => e.chat.gid == key.value);
        return at < 0 ? null : at;
      },
    );
  }
}
