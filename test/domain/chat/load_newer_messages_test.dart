import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/load_newer_messages.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  late _Repo repo;
  late LoadNewerMessages loadNewer;
  final newest = ChatMessage(
    accountId: 'a',
    gid: 'm50',
    chatGid: 'g',
    serverId: 9050,
    index: 50,
    senderId: 1,
    sentAt: DateTime(2026, 10, 10),
    content: const MessageContent.text('hi'),
    isMine: false,
  );

  void newer(Result<int> result) => when(
    () => repo.loadNewerMessages(
      any(),
      any(),
      afterServerId: any(named: 'afterServerId'),
    ),
  ).thenAnswer((_) async => result);

  void join(Result<int?> result) => when(
    () => repo.joinWindowToTimeline(
      any(),
      any(),
      fromIndex: any(named: 'fromIndex'),
      toIndex: any(named: 'toIndex'),
    ),
  ).thenAnswer((_) async => result);

  setUp(() {
    repo = _Repo();
    loadNewer = LoadNewerMessages(repo);
  });

  Future<Result<NewerMessages>> run() => loadNewer(
    accountId: 'a',
    chatGid: 'g',
    newestShown: newest,
    windowFrom: 1,
  );

  test('newer messages extend the window', () async {
    newer(const Ok(50));

    final result = await run();

    expect(result.valueOrNull, (added: 50, joined: null));
    verify(
      () => repo.loadNewerMessages('a', 'g', afterServerId: 9050),
    ).called(1);
    verifyNever(
      () => repo.joinWindowToTimeline(
        any(),
        any(),
        fromIndex: any(named: 'fromIndex'),
        toIndex: any(named: 'toIndex'),
      ),
    );
  });

  test('with nothing newer the window joins the timeline', () async {
    newer(const Ok(0));
    join(const Ok(120));

    final result = await run();

    expect(result.valueOrNull, (added: 0, joined: 120));
    verify(
      () => repo.joinWindowToTimeline('a', 'g', fromIndex: 1, toIndex: 50),
    ).called(1);
  });

  test('a window that cannot join stays apart', () async {
    newer(const Ok(0));
    join(const Ok(null));

    expect((await run()).valueOrNull, (added: 0, joined: null));
  });

  test('a failed fetch is reported', () async {
    newer(const Err(NetworkFailure('offline')));

    expect(await run(), isA<Err<NewerMessages>>());
  });

  test('a message without an index cannot be extended from', () async {
    final result = await loadNewer(
      accountId: 'a',
      chatGid: 'g',
      newestShown: newest.copyWith(index: null),
      windowFrom: 1,
    );

    expect(result.valueOrNull, (added: 0, joined: null));
    verifyZeroInteractions(repo);
  });
}
