import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';
import 'package:work_nexus/features/board/presentation/board_refresh.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';

class _MockSyncService extends Mock implements SyncService {}

const _product = ProviderProduct(
  id: '4',
  name: 'VN_Socialfi',
  accountId: 'zentao',
);

const _execution = ProviderExecution(
  id: '9',
  name: 'Sprint 9',
  projectId: '2',
  accountId: 'zentao',
);

void main() {
  late _MockSyncService sync;

  setUpAll(() => registerFallbackValue(_execution));

  setUp(() async {
    sync = _MockSyncService();
    await getIt.reset();
    getIt.registerSingleton<SyncService>(sync);
  });

  tearDown(() => getIt.reset());

  test('refreshing the bug board drops the cached tab and refetches', () async {
    when(
      () => sync.syncProductBugsTab(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: any(named: 'browseType'),
      ),
    ).thenAnswer((_) async => const Ok(['zentao:bug:4808']));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(viewModeProvider.notifier).set(ViewMode.zentaoBugs);
    container.read(selectedZenTaoProductProvider.notifier).select(_product);
    container.listen(zentaoBugTabSliceProvider, (_, _) {});
    await container.read(zentaoBugTabSliceProvider.future);

    await container.read(refreshBoardProvider)();
    await container.read(zentaoBugTabSliceProvider.future);

    verify(
      () => sync.invalidateProductBugsTab(
        accountId: 'zentao',
        productId: '4',
        browseType: 'unclosed',
      ),
    ).called(1);
    verify(
      () => sync.syncProductBugsTab(
        accountId: 'zentao',
        productId: '4',
        browseType: 'unclosed',
      ),
    ).called(2);
  });

  test('refreshing the task board re-syncs the open execution', () async {
    when(
      () => sync.syncExecutionTasks(any()),
    ).thenAnswer((_) async => const Ok(3));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(viewModeProvider.notifier).set(ViewMode.zentaoTasks);
    container.read(selectedZenTaoExecutionProvider.notifier).select(_execution);

    final result = await container.read(refreshBoardProvider)();

    expect(result, isA<Ok<void>>());
    verify(
      () =>
          sync.invalidateExecutionTasks(accountId: 'zentao', executionId: '9'),
    ).called(1);
    verify(() => sync.syncExecutionTasks(any())).called(1);
    // The syncing indicator is released once the refetch finishes.
    expect(container.read(zentaoExecutionSyncingProvider), isNull);
  });

  test('a failed task-board refresh reports the failure', () async {
    when(
      () => sync.syncExecutionTasks(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(viewModeProvider.notifier).set(ViewMode.zentaoTasks);
    container.read(selectedZenTaoExecutionProvider.notifier).select(_execution);

    final result = await container.read(refreshBoardProvider)();

    expect(result.failureOrNull?.message, 'offline');
    expect(container.read(zentaoExecutionSyncingProvider), isNull);
  });

  test('refreshing with no board open is a no-op', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(refreshBoardProvider)();

    expect(result, isA<Ok<void>>());
    expect(container.read(boardRefreshingProvider), isFalse);
    verifyZeroInteractions(sync);
  });
}
