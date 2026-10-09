import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/board/domain/value_objects/zentao_bug_browse_type.dart';
import 'package:work_nexus/features/board/domain/value_objects/zentao_bug_column.dart';
import 'package:work_nexus/features/board/domain/value_objects/zentao_bug_stream.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';

class _MockSyncService extends Mock implements SyncService {}

const _product = ProviderProduct(id: '4', name: 'P', accountId: 'zentao');

Ticket _bug(int id) => Ticket(
  id: 'zentao:bug:$id',
  accountId: 'zentao',
  projectId: 'zentao:P',
  providerType: ProviderType.zentao,
  externalKey: '$id',
  externalType: 'Bug',
  title: 'Bug $id',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
);

void main() {
  late _MockSyncService sync;

  setUp(() async {
    sync = _MockSyncService();
    await getIt.reset();
    getIt.registerSingleton<SyncService>(sync);
  });

  tearDown(() => getIt.reset());

  /// Answers [view]'s pages with two bugs each out of [total].
  void serve(String view, {int total = 3}) =>
      when(
        () => sync.syncProductBugsPage(
          accountId: any(named: 'accountId'),
          productId: any(named: 'productId'),
          browseType: view,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((call) async {
        final page = call.namedArguments[#page] as int;
        return Ok(
          BugPage(
            tickets: [_bug(view.length * 100 + page)],
            total: total,
            hasMore: page < total,
          ),
        );
      });

  ProviderContainer open() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedZenTaoProductProvider.notifier).select(_product);
    container.listen(zentaoBugStreamsProvider, (_, _) {});
    container.listen(zentaoBugSliceProvider, (_, _) {});
    return container;
  }

  test(
    'opening a product loads the first page of every opening view',
    () async {
      for (final v in ['unconfirmed', 'unresolved', 'toclosed']) {
        serve(v);
      }
      final container = open();
      expect(container.read(zentaoBugSliceProvider).isLoading, isTrue);
      await pumpEventQueue();

      final streams = container.read(zentaoBugStreamsProvider);
      expect(streams[ZenTaoBugStream.toClose]?.page, 1);
      expect(streams[ZenTaoBugStream.toClose]?.hasMore, isTrue);
      // Closed's view waits until its column asks.
      expect(streams[ZenTaoBugStream.all]?.started, isFalse);
      expect(container.read(zentaoBugSliceProvider).value, hasLength(3));
    },
  );

  test('load more appends the next page until the view ends', () async {
    for (final v in ['unconfirmed', 'unresolved', 'toclosed']) {
      serve(v, total: 2);
    }
    final container = open();
    await pumpEventQueue();
    final controller = container.read(zentaoBugStreamsProvider.notifier);

    await controller.loadMore(ZenTaoBugStream.unresolved);
    await controller.loadMore(ZenTaoBugStream.unresolved);

    final state = container.read(
      zentaoBugColumnStreamProvider(ZenTaoBugColumn.confirmedToFix),
    );
    expect(state.page, 2);
    expect(state.hasMore, isFalse);
    expect(state.ids, hasLength(2));
    verify(
      () => sync.syncProductBugsPage(
        accountId: 'zentao',
        productId: '4',
        browseType: 'unresolved',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).called(2);
  });

  test('a failed page waits for a retry', () async {
    serve('unconfirmed');
    serve('unresolved');
    when(
      () => sync.syncProductBugsPage(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: 'toclosed',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    final container = open();
    await pumpEventQueue();
    final controller = container.read(zentaoBugStreamsProvider.notifier);

    final failed = container.read(
      zentaoBugStreamsProvider,
    )[ZenTaoBugStream.toClose];
    expect(failed?.failure, isNotNull);
    expect(failed?.canLoadMore, isFalse);
    // The other views still show.
    expect(container.read(zentaoBugSliceProvider).value, hasLength(2));

    serve('toclosed');
    await controller.retry(ZenTaoBugStream.toClose);
    expect(
      container.read(zentaoBugStreamsProvider)[ZenTaoBugStream.toClose]?.page,
      1,
    );
  });

  test('the board keeps loading Closed only on the All tab', () async {
    for (final v in ['unconfirmed', 'unresolved', 'toclosed']) {
      serve(v, total: 1);
    }
    final container = open();
    container.listen(zentaoBugHasMoreProvider, (_, _) {});
    await pumpEventQueue();

    container
        .read(zentaoBugTabProvider.notifier)
        .set(ZenTaoBugBrowseType.unclosed);
    expect(container.read(zentaoBugHasMoreProvider), isFalse);
    container.read(zentaoBugTabProvider.notifier).set(ZenTaoBugBrowseType.all);
    expect(container.read(zentaoBugHasMoreProvider), isTrue);
  });
}
