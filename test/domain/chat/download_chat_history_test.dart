import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/download_chat_history.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_history_progress.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_timeline_extent.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  late _Repo repo;
  late List<ChatTimelineExtent> extents;

  Future<Result<int>> loadOlder() => repo.loadOlderMessages(
    any(),
    any(),
    beforeServerId: any(named: 'beforeServerId'),
    pageSize: any(named: 'pageSize'),
  );

  setUp(() {
    repo = _Repo();
    extents = [];
    // Each read of the timeline returns the next extent, the last one after.
    when(() => repo.timelineExtent(any(), any())).thenAnswer(
      (_) async => Ok(extents.length > 1 ? extents.removeAt(0) : extents.first),
    );
    when(
      () => repo.messageCount(any(), any()),
    ).thenAnswer((_) async => const Ok(120));
    when(loadOlder).thenAnswer((_) async => const Ok(50));
  });

  Future<List<Result<ChatHistoryProgress>>> run() =>
      DownloadChatHistory(repo)(accountId: 'a', chatGid: 'g').toList();

  List<ChatHistoryProgress?> values(List<Result<ChatHistoryProgress>> r) => [
    for (final x in r) x.valueOrNull,
  ];

  test('pages back from the oldest timeline message to the start', () async {
    extents = [
      const ChatTimelineExtent(count: 50, oldestServerId: 71),
      const ChatTimelineExtent(count: 100, oldestServerId: 21),
      const ChatTimelineExtent(
        count: 120,
        oldestServerId: 1,
        reachesStart: true,
      ),
    ];

    final results = await run();

    expect(values(results), const [
      ChatHistoryProgress(stored: 50, total: 120),
      ChatHistoryProgress(stored: 100, total: 120),
      ChatHistoryProgress(stored: 120, total: 120, complete: true),
    ]);
    verifyInOrder([
      () => repo.loadOlderMessages('a', 'g', beforeServerId: 71, pageSize: 200),
      () => repo.loadOlderMessages('a', 'g', beforeServerId: 21, pageSize: 200),
    ]);
  });

  test(
    'a history already stored to the start asks the server nothing',
    () async {
      extents = [
        const ChatTimelineExtent(
          count: 7,
          oldestServerId: 1,
          reachesStart: true,
        ),
      ];

      expect(values(await run()), const [
        ChatHistoryProgress(stored: 7, total: 7, complete: true),
      ]);
      verifyNever(() => repo.messageCount(any(), any()));
      verifyNever(loadOlder);
    },
  );

  test('with nothing stored the newest page comes first', () async {
    extents = [
      const ChatTimelineExtent(count: 0),
      const ChatTimelineExtent(
        count: 20,
        oldestServerId: 1,
        reachesStart: true,
      ),
    ];
    when(
      () => repo.refreshMessages(any(), any()),
    ).thenAnswer((_) async => const Ok(null));

    expect(values(await run()), const [
      ChatHistoryProgress(stored: 20, total: 120, complete: true),
    ]);
    verify(() => repo.refreshMessages('a', 'g')).called(1);
  });

  test('the server having nothing older ends it', () async {
    extents = [const ChatTimelineExtent(count: 118, oldestServerId: 3)];
    when(loadOlder).thenAnswer((_) async => const Ok(0));

    expect(
      values(await run()).last,
      const ChatHistoryProgress(stored: 118, total: 120, complete: true),
    );
  });

  test('a page that reaches no further back ends it', () async {
    extents = [const ChatTimelineExtent(count: 60, oldestServerId: 40)];

    final results = await run();

    expect(values(results).last?.complete, isTrue);
    verify(loadOlder).called(1);
  });

  test('a failed page ends it with the failure', () async {
    extents = [const ChatTimelineExtent(count: 50, oldestServerId: 71)];
    when(
      loadOlder,
    ).thenAnswer((_) async => const Err(NetworkFailure('Chat is offline')));

    final results = await run();

    expect(results, hasLength(2));
    expect(results.last.failureOrNull, isA<NetworkFailure>());
  });

  test('cancelling stops before the next page', () async {
    extents = [const ChatTimelineExtent(count: 50, oldestServerId: 71)];

    await DownloadChatHistory(repo)(accountId: 'a', chatGid: 'g').first;

    verifyNever(loadOlder);
  });

  group('back to a date', () {
    final since = DateTime(2026, 10, 2);

    Future<List<Result<ChatHistoryProgress>>> runSince() => DownloadChatHistory(
      repo,
    )(accountId: 'a', chatGid: 'g', since: since).toList();

    test('stops once the stored history reaches the date', () async {
      extents = [
        ChatTimelineExtent(
          count: 50,
          oldestServerId: 71,
          oldestSentAt: DateTime(2026, 10, 9),
        ),
        ChatTimelineExtent(
          count: 100,
          oldestServerId: 21,
          oldestSentAt: DateTime(2026, 9, 28),
        ),
      ];

      final results = await runSince();

      expect(values(results), const [
        ChatHistoryProgress(stored: 50, total: 0),
        ChatHistoryProgress(stored: 100, total: 100, complete: true),
      ]);
      verify(loadOlder).called(1);
      // The server counts the whole chat, not back to a date.
      verifyNever(() => repo.messageCount(any(), any()));
    });

    test('asks the server nothing when the date is already stored', () async {
      extents = [
        ChatTimelineExtent(
          count: 80,
          oldestServerId: 30,
          oldestSentAt: DateTime(2026, 9, 2),
        ),
      ];

      expect(values(await runSince()), const [
        ChatHistoryProgress(stored: 80, total: 80, complete: true),
      ]);
      verifyNever(loadOlder);
    });
  });
}
