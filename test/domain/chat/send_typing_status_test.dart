import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_typing_status.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;
  late SendTypingStatus send;

  setUp(() {
    repo = _MockChatRepository();
    send = SendTypingStatus(repo);
    when(
      () => repo.sendTyping(any(), any(), typing: any(named: 'typing')),
    ).thenAnswer((_) async => const Ok(null));
  });

  ChatConversation chat(ChatType type, {bool myCloud = false}) =>
      ChatConversation(
        accountId: 'a',
        gid: 'g',
        type: type,
        name: '',
        isMyCloud: myCloud,
      );

  test('sends in one-to-one chats and groups', () async {
    await send(chat: chat(ChatType.one2one), typing: true);
    await send(chat: chat(ChatType.group), typing: false);

    verify(() => repo.sendTyping('a', 'g', typing: true)).called(1);
    verify(() => repo.sendTyping('a', 'g', typing: false)).called(1);
  });

  test('sends nothing to My Cloud, bots or system chats', () async {
    for (final c in [
      chat(ChatType.one2one, myCloud: true),
      chat(ChatType.bot),
      chat(ChatType.system),
      chat(ChatType.other),
    ]) {
      expect((await send(chat: c, typing: true)).isOk, isTrue);
    }

    verifyNever(
      () => repo.sendTyping(any(), any(), typing: any(named: 'typing')),
    );
  });
}
