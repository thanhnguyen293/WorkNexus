import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/mappers/chat_mappers.dart';

const _chat = ChatConversationRow(
  accountId: 'acc',
  gid: 'g1',
  type: 'group',
  name: 'Team',
  lastMessageIndex: 10,
  lastReadIndex: 9,
  hidden: false,
  archived: false,
  pinnedJson: '[]',
  starred: false,
  muted: false,
  adminsJson: '[]',
  committers: '',
);

ChatMessageRow _last(int sender) => ChatMessageRow(
  accountId: 'acc',
  gid: 'm10',
  cgid: 'g1',
  senderId: sender,
  sentAt: DateTime(2026),
  contentType: 'text',
  content: 'hi',
  sendState: 'sent',
  deleted: false,
  detached: false,
  broadcast: false,
);

void main() {
  test('someone else\'s last message past the read mark is unread', () {
    final chat = conversationFromRow(
      _chat,
      lastMessage: _last(31),
      selfUserId: 40,
    );
    expect(chat.unreadCount, 1);
  });

  test('your own last message is never unread', () {
    final chat = conversationFromRow(
      _chat,
      lastMessage: _last(40),
      selfUserId: 40,
    );
    expect(chat.unreadCount, 0);
  });

  group('My Cloud', () {
    ChatConversationRow direct(String gid) =>
        _chat.copyWith(gid: gid, type: 'one2one', name: '');

    test('the one-to-one chat with yourself is My Cloud', () {
      final chat = conversationFromRow(direct('40&40'), selfUserId: 40);
      expect(chat.isMyCloud, isTrue);
      expect(chat.peerUserId, 40);
    });

    test('a chat with someone else is not', () {
      final chat = conversationFromRow(direct('31&40'), selfUserId: 40);
      expect(chat.isMyCloud, isFalse);
      expect(chat.peerUserId, 31);
    });

    test('nothing is My Cloud before your user id is known', () {
      expect(conversationFromRow(direct('40&40')).isMyCloud, isFalse);
    });
  });
}
