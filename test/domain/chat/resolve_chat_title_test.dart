import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_user.dart';
import 'package:work_nexus/features/chat/domain/usecases/resolve_chat_title.dart';

void main() {
  const resolve = ResolveChatTitle();
  const users = {
    31: ChatUser(
      accountId: 'a',
      userId: 31,
      account: 'dyno',
      realname: 'Dyno-VN',
    ),
    32: ChatUser(accountId: 'a', userId: 32, account: 'tram', realname: ''),
  };

  ChatConversation chat(ChatType type, {String name = '', int? peer}) =>
      ChatConversation(
        accountId: 'a',
        gid: 'g',
        type: type,
        name: name,
        peerUserId: peer,
      );

  test('one-to-one chats are titled after the other member', () {
    expect(resolve(chat(ChatType.one2one, peer: 31), users), 'Dyno-VN');
    expect(resolve(chat(ChatType.one2one, peer: 32), users), 'tram');
    expect(resolve(chat(ChatType.one2one, peer: 99), users), isNull);
  });

  test('other chats use their own name, null when blank', () {
    expect(
      resolve(chat(ChatType.group, name: ' VN Mobile '), users),
      'VN Mobile',
    );
    expect(resolve(chat(ChatType.bot, name: '阿道'), users), '阿道');
    expect(resolve(chat(ChatType.group), users), isNull);
  });
}
