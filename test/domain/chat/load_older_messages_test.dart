import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/load_older_messages.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  late _Repo repo;
  final oldest = ChatMessage(
    accountId: 'a',
    gid: 'm1',
    chatGid: 'g',
    serverId: 71,
    senderId: 1,
    sentAt: DateTime(2026, 10, 8, 15, 42),
    content: const MessageContent.text('hi'),
    isMine: false,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repo = _Repo();
    when(
      () => repo.loadOlderMessages(
        any(),
        any(),
        beforeServerId: any(named: 'beforeServerId'),
      ),
    ).thenAnswer((_) async => const Ok(50));
  });

  test('stored older messages are shown without asking the server', () async {
    when(
      () => repo.countOlderMessages(any(), any(), before: any(named: 'before')),
    ).thenAnswer((_) async => const Ok(140));

    final result = await LoadOlderMessages(repo)(
      accountId: 'a',
      chatGid: 'g',
      oldestShown: oldest,
    );

    expect(result.valueOrNull, 140);
    verifyNever(
      () => repo.loadOlderMessages(
        any(),
        any(),
        beforeServerId: any(named: 'beforeServerId'),
      ),
    );
  });

  test('otherwise the server pages from the oldest message shown', () async {
    when(
      () => repo.countOlderMessages(any(), any(), before: any(named: 'before')),
    ).thenAnswer((_) async => const Ok(0));

    final result = await LoadOlderMessages(repo)(
      accountId: 'a',
      chatGid: 'g',
      oldestShown: oldest,
    );

    expect(result.valueOrNull, 50);
    verify(() => repo.loadOlderMessages('a', 'g', beforeServerId: 71));
  });

  test('in a jump window the server is asked, stored ones or not', () async {
    when(
      () => repo.loadOlderMessages(
        any(),
        any(),
        beforeServerId: any(named: 'beforeServerId'),
        inWindow: any(named: 'inWindow'),
      ),
    ).thenAnswer((_) async => const Ok(50));

    final result = await LoadOlderMessages(repo)(
      accountId: 'a',
      chatGid: 'g',
      oldestShown: oldest,
      inWindow: true,
    );

    expect(result.valueOrNull, 50);
    verifyNever(
      () => repo.countOlderMessages(any(), any(), before: any(named: 'before')),
    );
    verify(
      () =>
          repo.loadOlderMessages('a', 'g', beforeServerId: 71, inWindow: true),
    ).called(1);
  });
}
