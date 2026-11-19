import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/chat_panic_chat_gateway.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_conversation.dart';

class _MockChats extends Mock implements ChatRepository {}

void main() {
  late _MockChats chats;
  late ChatPanicChatGateway gateway;

  setUp(() {
    chats = _MockChats();
    gateway = ChatPanicChatGateway(chats);
  });

  test('maps chat kinds, My Cloud and hidden chats', () async {
    when(() => chats.watchConversations('a1')).thenAnswer(
      (_) => Stream.value(const [
        ChatConversation(
          accountId: 'a1',
          gid: 'g',
          type: ChatType.group,
          name: 'Team',
          hidden: true,
        ),
        ChatConversation(
          accountId: 'a1',
          gid: 'dm',
          type: ChatType.one2one,
          name: '',
          peerUserId: 2,
          isMyCloud: true,
        ),
        ChatConversation(
          accountId: 'a1',
          gid: 'b',
          type: ChatType.bot,
          name: 'Bot',
        ),
      ]),
    );

    final mapped = await gateway.watchConversations('a1').first;

    expect(mapped, const [
      PanicConversation(
        gid: 'g',
        kind: PanicChatKind.group,
        name: 'Team',
        hidden: true,
      ),
      PanicConversation(
        gid: 'dm',
        kind: PanicChatKind.direct,
        name: '',
        peerUserId: 2,
        isSelf: true,
      ),
      PanicConversation(gid: 'b', kind: PanicChatKind.other, name: 'Bot'),
    ]);
  });

  test('passes an image name on, and none for other messages', () async {
    final at = DateTime(2026, 11, 19);
    ChatMessage message(MessageContent content) => ChatMessage(
      accountId: 'a1',
      gid: 'm',
      chatGid: 'g',
      senderId: 7,
      sentAt: at,
      isMine: false,
      content: content,
    );
    when(chats.watchIncoming).thenAnswer(
      (_) => Stream.fromIterable([
        message(
          const MessageContent.image(
            fileId: 1,
            name: 'sticker.png',
            size: 1,
            time: 0,
          ),
        ),
        message(const MessageContent.text('sticker.png')),
      ]),
    );

    final mapped = await gateway.watchIncoming().toList();

    expect(mapped.map((m) => m.imageName), ['sticker.png', null]);
    expect(mapped.first.senderId, 7);
    expect(mapped.first.sentAt, at);
  });

  test('maps users to members', () async {
    when(() => chats.watchUsers('a1')).thenAnswer(
      (_) => Stream.value(const [
        ChatUser(
          accountId: 'a1',
          userId: 3,
          account: 'an',
          realname: '',
          avatarUrl: 'u',
        ),
      ]),
    );

    final member = (await gateway.watchUsers('a1').first).single;

    expect(member.userId, 3);
    expect(member.displayName, 'an');
    expect(member.avatarUrl, 'u');
  });
}
