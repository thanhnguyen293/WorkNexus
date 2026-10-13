import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/usecases/count_tab_unread.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_list_tab.dart';

ChatConversation _chat(
  String gid,
  ChatType type,
  int unread, {
  bool hidden = false,
  bool archived = false,
}) => ChatConversation(
  accountId: 'acc',
  gid: gid,
  type: type,
  name: gid,
  unreadCount: unread,
  hidden: hidden,
  archived: archived,
);

void main() {
  const count = CountTabUnread();
  final chats = [
    _chat('dm', ChatType.one2one, 2),
    _chat('group', ChatType.group, 3),
    _chat('bot', ChatType.bot, 1),
    _chat('system', ChatType.system, 4),
  ];

  test('counts only the chats the tab shows', () {
    expect(count(chats, ChatListTab.all), 10);
    expect(count(chats, ChatListTab.direct), 2);
    expect(count(chats, ChatListTab.groups), 3);
    expect(count(chats, ChatListTab.bots), 5);
  });

  test('leaves out hidden and archived chats', () {
    expect(
      count([
        _chat('dm', ChatType.one2one, 1),
        _chat('hidden', ChatType.one2one, 5, hidden: true),
        _chat('archived', ChatType.one2one, 6, archived: true),
      ], ChatListTab.direct),
      1,
    );
  });
}
