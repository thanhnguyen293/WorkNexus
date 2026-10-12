import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/send_code_message.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;
  late SendCodeMessage send;

  setUp(() {
    repo = _MockChatRepository();
    send = SendCodeMessage(repo);
  });

  test('sends the code verbatim, with a trimmed name', () async {
    when(
      () => repo.sendCode(
        any(),
        any(),
        code: any(named: 'code'),
        language: any(named: 'language'),
        name: any(named: 'name'),
        replyToId: any(named: 'replyToId'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await send(
      accountId: 'a',
      chatGid: 'g',
      code: '  x := 1\n',
      language: 'go',
      name: ' main.go ',
      replyToId: 7,
    );

    expect(result.isOk, isTrue);
    verify(
      () => repo.sendCode(
        'a',
        'g',
        code: '  x := 1\n',
        language: 'go',
        name: 'main.go',
        replyToId: 7,
      ),
    ).called(1);
  });

  test('a blank name is sent as none, in plain text by default', () async {
    when(
      () => repo.sendCode(
        any(),
        any(),
        code: any(named: 'code'),
        language: any(named: 'language'),
        name: any(named: 'name'),
        replyToId: any(named: 'replyToId'),
      ),
    ).thenAnswer((_) async => const Ok(null));

    await send(accountId: 'a', chatGid: 'g', code: 'abc', name: '  ');

    verify(() => repo.sendCode('a', 'g', code: 'abc', language: 'text'));
  });

  test('rejects blank or too-long code without sending', () async {
    final blank = await send(accountId: 'a', chatGid: 'g', code: ' \n\t');
    final long = await send(
      accountId: 'a',
      chatGid: 'g',
      code: 'x' * (SendCodeMessage.maxLength + 1),
    );

    expect(blank.failureOrNull, isA<ValidationFailure>());
    expect(long.failureOrNull, isA<ValidationFailure>());
    verifyNever(
      () => repo.sendCode(
        any(),
        any(),
        code: any(named: 'code'),
        language: any(named: 'language'),
      ),
    );
  });
}
