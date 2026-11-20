import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_link_to_chats.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_text_message.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;
  late SendLinkToChats share;

  const link = 'https://zt.example/task-view-7.html';

  setUp(() {
    repo = _MockChatRepository();
    share = SendLinkToChats(SendTextMessage(repo));
    when(
      () => repo.sendText(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('puts the note above the link, on a line of its own', () {
    expect(
      SendLinkToChats.compose(link, note: '  Check this \n'),
      'Check this\n$link',
    );
    expect(SendLinkToChats.compose(link, note: ' \n'), link);
  });

  test('sends one message to each chat', () async {
    final result = await share(
      accountId: 'a',
      link: link,
      note: 'Check this',
      toChatGids: ['g1', 'g2'],
    );

    expect(result.isOk, isTrue);
    for (final gid in ['g1', 'g2']) {
      verify(() => repo.sendText('a', gid, 'Check this\n$link')).called(1);
    }
  });

  test('one chat failing does not stop the others', () async {
    when(
      () => repo.sendText('a', 'g1', any()),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));

    final result = await share(
      accountId: 'a',
      link: link,
      toChatGids: ['g1', 'g2'],
    );

    expect(result.failureOrNull, isA<NetworkFailure>());
    verify(() => repo.sendText('a', 'g2', link)).called(1);
  });

  test('refuses without a chat or a link, sending nothing', () async {
    expect(
      (await share(accountId: 'a', link: link, toChatGids: [])).failureOrNull,
      isA<UnexpectedFailure>(),
    );
    expect(
      (await share(
        accountId: 'a',
        link: ' ',
        toChatGids: ['g1'],
      )).failureOrNull,
      isA<UnexpectedFailure>(),
    );
    verifyNever(() => repo.sendText(any(), any(), any()));
  });
}
