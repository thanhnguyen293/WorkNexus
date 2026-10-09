import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/usecases/can_send_to_chat.dart';

ChatConversation _chat(String committers, {List<int> admins = const []}) =>
    ChatConversation(
      accountId: 'acc',
      gid: 'g1',
      type: ChatType.system,
      name: '系统',
      committers: committers,
      adminIds: admins,
      ownerAccount: 'owner',
    );

void main() {
  const canSend = CanSendToChat();

  bool as(ChatConversation chat, {int id = 40, String account = 'thanh'}) =>
      canSend(chat, selfUserId: id, selfAccount: account);

  test('everyone may send when committers is empty or \$ALL', () {
    expect(as(_chat('')), isTrue);
    expect(as(_chat(r'$ALL')), isTrue);
  });

  test('\$ADMINS lets only admins and the owner send', () {
    expect(as(_chat(r'$ADMINS')), isFalse);
    expect(as(_chat(r'$ADMINS', admins: [40])), isTrue);
    expect(as(_chat(r'$ADMINS'), id: 1, account: 'owner'), isTrue);
  });

  test('a list lets the ids or accounts on it send', () {
    expect(as(_chat('12, 40')), isTrue);
    expect(as(_chat('thanh,dyno')), isTrue);
    expect(as(_chat('12,dyno')), isFalse);
  });
}
