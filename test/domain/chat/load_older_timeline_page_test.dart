import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_local_api.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/load_older_timeline_page.dart';
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
    when(loadOlder).thenAnswer((_) async => const Ok(100));
    when(
      () => repo.refreshMessages(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<Result<ChatHistoryStep>> run({int pageSize = 100}) =>
      LoadOlderTimelinePage(repo)(
        accountId: 'a',
        chatGid: 'g',
        pageSize: pageSize,
      );

  test('pages back from the oldest timeline message', () async {
    extents = [
      const ChatTimelineExtent(count: 50, oldestServerId: 500),
      const ChatTimelineExtent(count: 150, oldestServerId: 400),
    ];

    final result = await run(pageSize: 1000);

    expect(result.valueOrNull, (loaded: 100, reachesStart: false));
    verify(
      () => repo.loadOlderMessages(
        'a',
        'g',
        beforeServerId: 500,
        pageSize: LoadOlderTimelinePage.maxPageSize,
      ),
    ).called(1);
  });

  test('asks nothing once the timeline holds the first message', () async {
    extents = [
      const ChatTimelineExtent(count: 9, oldestServerId: 1, reachesStart: true),
    ];

    expect((await run()).valueOrNull, (loaded: 0, reachesStart: true));
    verifyNever(loadOlder);
  });

  test('fetches the newest page when nothing is stored', () async {
    extents = [
      const ChatTimelineExtent(count: 0),
      const ChatTimelineExtent(count: 30, oldestServerId: 70),
    ];

    expect((await run()).valueOrNull, (loaded: 30, reachesStart: false));
    verify(() => repo.refreshMessages('a', 'g')).called(1);
    verifyNever(loadOlder);
  });

  test('a page that reaches no further back ends the history', () async {
    extents = [
      const ChatTimelineExtent(count: 50, oldestServerId: 500),
      const ChatTimelineExtent(count: 50, oldestServerId: 500),
    ];
    when(loadOlder).thenAnswer((_) async => const Ok(0));

    expect((await run()).valueOrNull, (loaded: 0, reachesStart: true));
  });

  test('passes on a failed page', () async {
    extents = [const ChatTimelineExtent(count: 50, oldestServerId: 500)];
    when(
      loadOlder,
    ).thenAnswer((_) async => const Err(NetworkFailure('Chat is offline')));

    expect((await run()).failureOrNull, isA<NetworkFailure>());
  });
}
