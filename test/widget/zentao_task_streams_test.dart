import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_task_column.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/util/cancel_signal.dart';
import 'package:work_nexus/shared/board/domain/entities/paged_view_state.dart';
import 'package:work_nexus/shared/board/domain/usecases/should_auto_load.dart';
import 'package:work_nexus/shared/board/domain/value_objects/paging_policy.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_view_pages.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_task_streams.dart';

class _MockViewPages extends Mock implements ZenTaoViewPages {}

const _execution = ProviderExecution(
  id: '9',
  name: 'Sprint 9',
  projectId: '2',
  accountId: 'zentao',
);

Ticket _task(int id) => Ticket(
  id: 'zentao:task:$id',
  accountId: 'zentao',
  projectId: 'zentao:P',
  providerType: ProviderType.zentao,
  externalKey: '$id',
  externalType: 'Task',
  title: 'Task $id',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'h',
);

void main() {
  late _MockViewPages sync;

  setUpAll(() => registerFallbackValue(CancelSignal()));

  setUp(() async {
    sync = _MockViewPages();
    await getIt.reset();
    getIt.registerSingleton<ZenTaoViewPages>(sync);
  });

  tearDown(getIt.reset);

  /// Answers [view]'s pages with one task each out of [total] pages.
  void serve(String view, {int total = 3}) =>
      when(
        () => sync.syncExecutionTasksPage(
          accountId: any(named: 'accountId'),
          executionId: any(named: 'executionId'),
          browseType: view,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).thenAnswer((call) async {
        final page = call.namedArguments[#page] as int;
        return Ok(
          ViewPage(
            tickets: [_task(_viewIndex(view) * 100 + page)],
            total: total,
            hasMore: page < total,
          ),
        );
      });

  void serveAll({int total = 3}) {
    for (final column in ZenTaoTaskColumn.values) {
      serve(column.browseType, total: total);
    }
  }

  ProviderContainer open() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedZenTaoExecutionProvider.notifier).select(_execution);
    container.listen(zentaoTaskStreamsProvider, (_, _) {});
    container.listen(zentaoTaskSliceProvider, (_, _) {});
    return container;
  }

  // A project scope (or none) has no execution to page: nothing loads, and
  // no column footer can ask for (and fail on) a page.
  test('with no execution picked, no view loads or fails', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(zentaoTaskStreamsProvider, (_, _) {});
    await pumpEventQueue();

    final controller = container.read(zentaoTaskStreamsProvider.notifier);
    for (final column in ZenTaoTaskColumn.values) {
      await controller.loadMore(column);
    }
    for (final view in container.read(zentaoTaskStreamsProvider).values) {
      expect(view.hasMore, isFalse);
      expect(view.failure, isNull);
    }
    verifyNever(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    );
  });

  test(
    'opening an execution loads only the first page of each status',
    () async {
      serveAll();
      final container = open();
      expect(container.read(zentaoTaskSliceProvider).isLoading, isTrue);
      await pumpEventQueue();

      final streams = container.read(zentaoTaskStreamsProvider);
      for (final column in ZenTaoTaskColumn.values) {
        expect(streams[column]?.page, 1);
        expect(streams[column]?.hasMore, isTrue);
        verify(
          () => sync.syncExecutionTasksPage(
            accountId: 'zentao',
            executionId: '9',
            browseType: column.browseType,
            page: 1,
            limit: kPagedViewPageSize,
            cancel: any(named: 'cancel'),
          ),
        ).called(1);
      }
      expect(
        container.read(zentaoTaskSliceProvider).value,
        hasLength(ZenTaoTaskColumn.values.length),
      );
    },
  );

  test('load more appends the next page until the view ends', () async {
    serveAll(total: 2);
    final container = open();
    await pumpEventQueue();
    final controller = container.read(zentaoTaskStreamsProvider.notifier);

    await controller.loadMore(ZenTaoTaskColumn.closed);
    await controller.loadMore(ZenTaoTaskColumn.closed);

    final state = container.read(
      zentaoTaskColumnStreamProvider(ZenTaoTaskColumn.closed),
    );
    expect(state.page, 2);
    expect(state.hasMore, isFalse);
    expect(state.ids, hasLength(2));
  });

  test('a failed page waits for a retry', () async {
    serveAll();
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: 'done',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final container = open();
    await pumpEventQueue();
    final controller = container.read(zentaoTaskStreamsProvider.notifier);

    final failed = container.read(
      zentaoTaskStreamsProvider,
    )[ZenTaoTaskColumn.doneVerify];
    expect(failed?.failure, isNotNull);
    expect(failed?.canLoadMore, isFalse);
    // The other columns still show.
    expect(
      container.read(zentaoTaskSliceProvider).value,
      hasLength(ZenTaoTaskColumn.values.length - 1),
    );

    serve('done');
    await controller.retry(ZenTaoTaskColumn.doneVerify);
    expect(
      container
          .read(zentaoTaskStreamsProvider)[ZenTaoTaskColumn.doneVerify]
          ?.page,
      1,
    );
  });

  test('the slice fails only when every status view failed', () async {
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final container = open();
    await pumpEventQueue();

    expect(container.read(zentaoTaskSliceProvider).hasError, isTrue);
    // Each failed view can still load once retried.
    expect(container.read(zentaoTaskHasMoreProvider), isTrue);
  });

  test('a failed view keeps the board up while the rest are empty', () async {
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer(
      (_) async => const Ok(ViewPage(tickets: [], total: 0, hasMore: false)),
    );
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: 'wait',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('timeout')));
    final container = open();
    container.listen(zentaoTaskHasMoreProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(zentaoTaskSliceProvider).hasError, isFalse);
    // So the board shows the failed column's Retry, not "no tickets".
    expect(container.read(zentaoTaskHasMoreProvider), isTrue);
  });

  test(
    'a page that throws fails its view instead of loading forever',
    () async {
      serveAll();
      when(
        () => sync.syncExecutionTasksPage(
          accountId: any(named: 'accountId'),
          executionId: any(named: 'executionId'),
          browseType: 'doing',
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).thenThrow(Exception('keychain locked'));
      final container = open();
      await pumpEventQueue();

      final failed = container.read(
        zentaoTaskStreamsProvider,
      )[ZenTaoTaskColumn.inProgress];
      expect(failed?.loading, isFalse);
      expect(failed?.failure, isA<UnexpectedFailure>());

      serve('doing');
      await container
          .read(zentaoTaskStreamsProvider.notifier)
          .retry(ZenTaoTaskColumn.inProgress);
      expect(
        container
            .read(zentaoTaskStreamsProvider)[ZenTaoTaskColumn.inProgress]
            ?.page,
        1,
      );
    },
  );

  test('a refresh drops the pages its cancel cut short', () async {
    serveAll();
    // The first `wait` page is still loading when the board is refreshed and,
    // like dio, answers the cancel with a failure — before the rebuild runs.
    var waitCalls = 0;
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: 'wait',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((call) async {
      if (waitCalls++ == 0) {
        await (call.namedArguments[#cancel] as CancelSignal).whenCancelled;
        return const Err(CancelledFailure('cancelled'));
      }
      return Ok(ViewPage(tickets: [_task(1)], total: 1, hasMore: false));
    });
    final container = open();
    await pumpEventQueue();

    container.invalidate(zentaoTaskStreamsProvider);
    await pumpEventQueue();

    final reopened = container.read(
      zentaoTaskStreamsProvider,
    )[ZenTaoTaskColumn.notStarted];
    expect(reopened?.failure, isNull);
    expect(reopened?.page, 1);
  });

  test('a filtered board fetches several pages per load', () async {
    serveAll(total: 500);
    final container = open();
    await pumpEventQueue();
    container.read(filterStateProvider.notifier).setSearch('report');

    await container
        .read(zentaoTaskStreamsProvider.notifier)
        .loadMore(ZenTaoTaskColumn.closed, visible: 0);

    final state = container.read(
      zentaoTaskColumnStreamProvider(ZenTaoTaskColumn.closed),
    );
    expect(state.page, 1 + kFilteredPagesPerLoad);
    for (var page = 2; page <= 1 + kFilteredPagesPerLoad; page++) {
      verify(
        () => sync.syncExecutionTasksPage(
          accountId: 'zentao',
          executionId: '9',
          browseType: 'closed',
          page: page,
          limit: kPagedViewPageSize,
          cancel: any(named: 'cancel'),
        ),
      ).called(1);
    }
  });

  test(
    'a filtered column stops loading by itself once loads turn up nothing',
    () async {
      serveAll(total: 50);
      final container = open();
      await pumpEventQueue();
      container.read(filterStateProvider.notifier).setSearch('nothing matches');
      final controller = container.read(zentaoTaskStreamsProvider.notifier);
      PagedViewState closed() => container.read(
        zentaoTaskColumnStreamProvider(ZenTaoTaskColumn.closed),
      );

      var loads = 0;
      while (_autoLoads(closed(), filtered: true, visible: 0)) {
        await controller.loadMore(ZenTaoTaskColumn.closed, visible: 0);
        loads++;
      }
      expect(loads, kMaxDryLoads + 1);
      // Unfiltered, the same column keeps loading; a new match resumes it too.
      expect(_autoLoads(closed(), filtered: false, visible: 0), isTrue);
      expect(_autoLoads(closed(), filtered: true, visible: 1), isTrue);
    },
  );

  test('opening another execution cancels the pages still loading', () async {
    final signals = <CancelSignal>[];
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((call) {
      signals.add(call.namedArguments[#cancel] as CancelSignal);
      return Completer<Result<ViewPage>>().future;
    });
    final container = open();
    await pumpEventQueue();
    expect(signals, isNotEmpty);
    expect(signals.any((s) => s.isCancelled), isFalse);

    container
        .read(selectedZenTaoExecutionProvider.notifier)
        .select(
          const ProviderExecution(
            id: '10',
            name: 'Sprint 10',
            projectId: '2',
            accountId: 'zentao',
          ),
        );
    container.read(zentaoTaskStreamsProvider);
    await pumpEventQueue();

    expect(
      signals.take(ZenTaoTaskColumn.values.length).every((s) => s.isCancelled),
      isTrue,
    );
  });

  test('opening the execution already open keeps its loaded pages', () async {
    serveAll();
    final container = open();
    await pumpEventQueue();
    await container
        .read(zentaoTaskStreamsProvider.notifier)
        .loadMore(ZenTaoTaskColumn.closed);

    container.read(selectedZenTaoExecutionProvider.notifier).select(_execution);
    await pumpEventQueue();

    expect(
      container
          .read(zentaoTaskColumnStreamProvider(ZenTaoTaskColumn.closed))
          .page,
      2,
    );
  });
}

int _viewIndex(String view) =>
    ZenTaoTaskColumn.values.indexWhere((c) => c.browseType == view);

bool _autoLoads(
  PagedViewState state, {
  required bool filtered,
  required int visible,
}) => const ShouldAutoLoad()(
  AutoLoadQuery(state: state, filtered: filtered, visible: visible),
);
