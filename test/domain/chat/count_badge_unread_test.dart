import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/usecases/count_badge_unread.dart';

ChatConversation _chat(
  String gid,
  int unread, {
  bool hidden = false,
  bool archived = false,
  bool muted = false,
}) => ChatConversation(
  accountId: 'acc',
  gid: gid,
  type: ChatType.group,
  name: gid,
  unreadCount: unread,
  hidden: hidden,
  archived: archived,
  muted: muted,
);

void main() {
  const count = CountBadgeUnread();

  test('adds up the unread messages of every followed chat', () {
    expect(count([_chat('a', 2), _chat('b', 3), _chat('c', 0)]), 5);
  });

  test('leaves out muted, hidden and archived chats', () {
    expect(
      count([
        _chat('a', 1),
        _chat('muted', 4, muted: true),
        _chat('hidden', 5, hidden: true),
        _chat('archived', 6, archived: true),
      ]),
      1,
    );
  });

  test('is zero with no chats', () {
    expect(count(const []), 0);
  });
}
