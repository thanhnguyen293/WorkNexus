import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/chat/data/mappers/chat_row_cache.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

ChatMessageRow _message(String gid, {String content = 'hi'}) => ChatMessageRow(
  accountId: 'acc',
  gid: gid,
  cgid: 'g1',
  senderId: 31,
  sentAt: DateTime(2026, 10, 10),
  contentType: 'plain',
  content: content,
  sendState: 'sent',
  deleted: false,
  detached: false,
  broadcast: false,
);

ChatConversationRow _chat({String name = 'Team'}) => ChatConversationRow(
  accountId: 'acc',
  gid: 'g1',
  type: 'group',
  name: name,
  lastMessageIndex: 3,
  lastReadIndex: 1,
  hidden: false,
  archived: false,
  pinnedJson: '[7]',
  starred: false,
  muted: false,
  adminsJson: '[]',
  committers: '',
);

void main() {
  late ChatRowCache cache;

  setUp(() => cache = ChatRowCache(const ParseMessageContent(), capacity: 2));

  test('an unchanged row keeps its message instance', () {
    final first = cache.message(_message('m1'), selfUserId: 31);
    final again = cache.message(_message('m1'), selfUserId: 31);
    expect(identical(first, again), isTrue);
    expect(first.isMine, isTrue);
  });

  test('a changed row, or another self, maps again', () {
    final first = cache.message(_message('m1'), selfUserId: 31);
    final edited = cache.message(
      _message('m1', content: 'bye'),
      selfUserId: 31,
    );
    expect(identical(first, edited), isFalse);
    expect(edited.content, const MessageContent.text('bye'));
    final other = cache.message(_message('m1', content: 'bye'), selfUserId: 9);
    expect(other.isMine, isFalse);
  });

  test('the oldest entries go once over capacity', () {
    final m1 = cache.message(_message('m1'));
    cache.message(_message('m2'));
    cache.message(_message('m3'));
    expect(identical(m1, cache.message(_message('m1'))), isFalse);
  });

  test('a conversation and its last message are reused together', () {
    final last = _message('m3');
    final first = cache.conversation(
      _chat(),
      lastMessage: last,
      selfUserId: 31,
    );
    final again = cache.conversation(
      _chat(),
      lastMessage: last,
      selfUserId: 31,
    );
    expect(identical(first, again), isTrue);
    expect(
      identical(first.lastMessage, cache.message(last, selfUserId: 31)),
      isTrue,
    );
    expect(first.pinnedMessageIds, [7]);
    final renamed = cache.conversation(_chat(name: 'Crew'), lastMessage: last);
    expect(renamed.name, 'Crew');
  });
}
