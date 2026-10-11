import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_text_message.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;
  late SendTextMessage send;

  setUp(() {
    repo = _MockChatRepository();
    send = SendTextMessage(repo);
  });

  test('trims and sends', () async {
    when(
      () => repo.sendText('a', 'g', 'hello'),
    ).thenAnswer((_) async => const Ok(null));

    final result = await send(accountId: 'a', chatGid: 'g', text: '  hello \n');

    expect(result.isOk, isTrue);
    verify(() => repo.sendText('a', 'g', 'hello')).called(1);
  });

  test('rejects a blank message without calling the repository', () async {
    final result = await send(accountId: 'a', chatGid: 'g', text: ' \n\t');

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    verifyNever(() => repo.sendText(any(), any(), any()));
  });

  test('markdown has trailing spaces moved out of emphasis', () async {
    when(
      () => repo.sendText('a', 'g', '**hi** there', markdown: true),
    ).thenAnswer((_) async => const Ok(null));

    await send(
      accountId: 'a',
      chatGid: 'g',
      text: '**hi **there',
      markdown: true,
    );

    verify(
      () => repo.sendText('a', 'g', '**hi** there', markdown: true),
    ).called(1);
  });
}
