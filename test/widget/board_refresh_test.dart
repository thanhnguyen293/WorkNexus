import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/util/cancel_signal.dart';
import 'package:work_nexus/features/board/domain/repositories/zentao_view_pages.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';
import 'package:work_nexus/features/board/presentation/board_refresh.dart';

class _MockViewPages extends Mock implements ZenTaoViewPages {}

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
  late _MockViewPages sync;

  setUpAll(() => registerFallbackValue(CancelSignal()));

  setUp(() async {
    sync = _MockViewPages();
    await getIt.reset();
    getIt.registerSingleton<ZenTaoViewPages>(sync);
  });

  tearDown(() => getIt.reset());

  test('refreshing the bug board reloads every view from page 1', () async {
    when(
      () => sync.syncProductBugsPage(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer(
      (_) async => const Ok(ViewPage(tickets: [], total: 0, hasMore: false)),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(viewModeProvider.notifier).set(ViewMode.zentaoBugs);
    container.read(selectedZenTaoProductProvider.notifier).select(_product);
    container.listen(zentaoBugSliceProvider, (_, _) {});
    await pumpEventQueue();

    await container.read(refreshBoardProvider)();
    container.read(zentaoBugSliceProvider);
    await pumpEventQueue();

    for (final view in ['unconfirmed', 'unresolved', 'toclosed']) {
      verify(
        () => sync.syncProductBugsPage(
          accountId: 'zentao',
          productId: '4',
          browseType: view,
          page: 1,
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).called(2);
    }
  });

  test(
    'refreshing the task board reloads every status view from page 1',
    () async {
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

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(viewModeProvider.notifier).set(ViewMode.zentaoTasks);
      container
          .read(selectedZenTaoExecutionProvider.notifier)
          .select(_execution);
      container.listen(zentaoTaskSliceProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(boardRefreshingProvider), isFalse);

      final result = await container.read(refreshBoardProvider)();
      container.read(zentaoTaskSliceProvider);
      await pumpEventQueue();

      expect(result, isA<Ok<void>>());
      for (final view in [
        'wait',
        'doing',
        'pause',
        'done',
        'closed',
        'cancel',
      ]) {
        verify(
          () => sync.syncExecutionTasksPage(
            accountId: 'zentao',
            executionId: '9',
            browseType: view,
            page: 1,
            limit: any(named: 'limit'),
            cancel: any(named: 'cancel'),
          ),
        ).called(2);
      }
    },
  );

  test('refreshing with no board open is a no-op', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(refreshBoardProvider)();

    expect(result, isA<Ok<void>>());
    expect(container.read(boardRefreshingProvider), isFalse);
    verifyZeroInteractions(sync);
  });
}
