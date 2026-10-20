import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_bug_column.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/core/util/cancel_signal.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_view_pages.dart';
import 'package:work_nexus/tools/zentao/domain/value_objects/zentao_bug_browse_type.dart';
import 'package:work_nexus/tools/zentao/domain/value_objects/zentao_bug_stream.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_bug_streams.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

class _MockViewPages extends Mock implements ZenTaoViewPages {}

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
  late _MockViewPages sync;

  setUpAll(() => registerFallbackValue(CancelSignal()));

  setUp(() async {
    sync = _MockViewPages();
    await getIt.reset();
    getIt.registerSingleton<ZenTaoViewPages>(sync);
  });

  tearDown(getIt.reset);

  /// Answers [view]'s pages with two bugs each out of [total].
  void serve(String view, {int total = 3}) =>
      when(
        () => sync.syncProductBugsPage(
          accountId: any(named: 'accountId'),
          productId: any(named: 'productId'),
          browseType: view,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).thenAnswer((call) async {
        final page = call.namedArguments[#page] as int;
        return Ok(
          ViewPage(
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

  // Bugs are listed per product only: with none picked, nothing is paged
  // and no column footer can ask for (and fail on) a page.
  test('with no product picked, no view loads or fails', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(zentaoBugStreamsProvider, (_, _) {});
    await pumpEventQueue();

    for (final column in ZenTaoBugColumn.values) {
      final view = container.read(zentaoBugColumnStreamProvider(column));
      expect(view.hasMore, isFalse, reason: column.name);
      expect(view.failure, isNull, reason: column.name);
    }
    expect(container.read(zentaoBugHasMoreProvider), isFalse);
    final controller = container.read(zentaoBugStreamsProvider.notifier);
    for (final view in ZenTaoBugStream.values) {
      await controller.loadMore(view);
    }
    expect(
      container.read(zentaoBugStreamsProvider).values.map((v) => v.failure),
      everyElement(isNull),
    );
    verifyNever(
      () => sync.syncProductBugsPage(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    );
  });

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
        cancel: any(named: 'cancel'),
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
        cancel: any(named: 'cancel'),
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

  test('a failed view keeps the board up while the rest are empty', () async {
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
    when(
      () => sync.syncProductBugsPage(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: 'toclosed',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure('timeout')));
    final container = open();
    container.listen(zentaoBugHasMoreProvider, (_, _) {});
    // Closed is off this tab, so only the failed view can keep the board up.
    container
        .read(zentaoBugTabProvider.notifier)
        .set(ZenTaoBugBrowseType.unclosed);
    await pumpEventQueue();

    expect(container.read(zentaoBugSliceProvider).hasError, isFalse);
    // So the board shows the failed column's Retry, not "no tickets".
    expect(container.read(zentaoBugHasMoreProvider), isTrue);
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

  test('Related to me loads one merged view that feeds every column', () async {
    // Assigned to, opened by and resolved by me, paged together.
    serve('assigntome', total: 2);
    serve('openedbyme', total: 1);
    serve('resolvedbyme', total: 1);
    final container = open();
    container.listen(zentaoBugHasMoreProvider, (_, _) {});
    container
        .read(zentaoBugTabProvider.notifier)
        .set(ZenTaoBugBrowseType.relatedToMe);
    await pumpEventQueue();

    final streams = container.read(zentaoBugStreamsProvider);
    expect(streams[ZenTaoBugStream.relatedToMe]?.page, 1);
    // The per-column views stay unloaded.
    for (final view in [
      ZenTaoBugStream.unconfirmed,
      ZenTaoBugStream.unresolved,
      ZenTaoBugStream.toClose,
      ZenTaoBugStream.all,
    ]) {
      expect(streams[view]?.started, isFalse, reason: view.name);
    }
    for (final column in ZenTaoBugColumn.values) {
      expect(
        container.read(zentaoBugColumnStreamProvider(column)).page,
        1,
        reason: column.name,
      );
    }
    // One bug from each view; 'assigntome' and 'openedbyme' happen to list
    // the same one, which is shown once.
    expect(container.read(zentaoBugSliceProvider).value, hasLength(2));
    // Only its own view counts toward loading more: one of its three has
    // another page.
    expect(container.read(zentaoBugHasMoreProvider), isTrue);
    await container
        .read(zentaoBugStreamsProvider.notifier)
        .loadMore(ZenTaoBugStream.relatedToMe);
    expect(container.read(zentaoBugHasMoreProvider), isFalse);
  });

  test('leaving Related to me loads the column views again', () async {
    serve('assigntome');
    for (final v in ['unconfirmed', 'unresolved', 'toclosed']) {
      serve(v);
    }
    final container = open();
    final tab = container.read(zentaoBugTabProvider.notifier);
    tab.set(ZenTaoBugBrowseType.relatedToMe);
    await pumpEventQueue();

    tab.set(ZenTaoBugBrowseType.unclosed);
    await pumpEventQueue();

    final streams = container.read(zentaoBugStreamsProvider);
    expect(streams[ZenTaoBugStream.unresolved]?.page, 1);
    expect(streams[ZenTaoBugStream.relatedToMe]?.started, isFalse);
  });

  test('until Assigned to me loads, the board keeps the cached bugs '
      'assigned to the user', () async {
    when(
      () => sync.syncProductBugsPage(
        accountId: any(named: 'accountId'),
        productId: any(named: 'productId'),
        browseType: 'assigntome',
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) => Completer<Result<ViewPage>>().future);
    Ticket cached(int id, String assignee) => _bug(
      id,
    ).copyWith(assignee: assignee, labels: const ['zentao-product:4']);
    final container = ProviderContainer(
      overrides: [
        toolRegistryProvider.overrideWithValue({
          ProviderType.zentao: const ZentaoModule(),
        }),
        ticketsProvider.overrideWith(
          (ref) => Stream.value([cached(1, 'me'), cached(2, 'bob')]),
        ),
        accountsProvider.overrideWith(
          (ref) => Stream.value(const [
            Account(
              id: 'zentao',
              workspaceId: 'w',
              providerType: ProviderType.zentao,
              handle: 'me',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier).selectAccount('zentao');
    container
        .read(appNavProvider.notifier)
        .selectSection(const SectionId('zentao.bugs'));
    // As the sidebar picks a product: its scope and the selection.
    container.read(appNavProvider.notifier).selectScope(_product.id);
    container.read(selectedZenTaoProductProvider.notifier).select(_product);
    container
        .read(zentaoBugTabProvider.notifier)
        .set(ZenTaoBugBrowseType.relatedToMe);
    container.listen(zentaoBugBoardProvider, (_, _) {});
    await pumpEventQueue();

    final shown = [
      for (final c in container.read(zentaoBugBoardProvider).columns)
        ...c.tickets.map((t) => t.id),
    ];
    expect(shown, ['zentao:bug:1']);
  });
}
