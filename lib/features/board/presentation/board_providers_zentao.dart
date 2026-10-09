part of 'board_providers.dart';

// ZenTao sources: product bug boards, project executions and their sidebar state.

/// Which ZenTao accounts have their collapsible "Projects" group expanded.
/// Empty by default, so every group starts collapsed.
class ZenTaoProjectsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final zentaoProjectsExpandedProvider =
    NotifierProvider<ZenTaoProjectsExpanded, Set<String>>(
      ZenTaoProjectsExpanded.new,
    );

class SelectedZenTaoProduct extends Notifier<ZenTaoProductSelection?> {
  @override
  ZenTaoProductSelection? build() => null;

  void select(ProviderProduct product) {
    state = ZenTaoProductSelection(
      accountId: product.accountId,
      productId: product.id,
      productName: product.name,
    );
  }

  void clear() => state = null;
}

final selectedZenTaoProductProvider =
    NotifierProvider<SelectedZenTaoProduct, ZenTaoProductSelection?>(
      SelectedZenTaoProduct.new,
    );

/// The selected bug-board tab (ZenTao browse type). Defaults to [unclosed],
/// matching ZenTao's own bug board; reset when switching products.
class ZenTaoBugTabController extends Notifier<ZenTaoBugBrowseType> {
  @override
  ZenTaoBugBrowseType build() => ZenTaoBugBrowseType.unclosed;

  void set(ZenTaoBugBrowseType tab) => state = tab;
  void reset() => state = ZenTaoBugBrowseType.unclosed;
}

final zentaoBugTabProvider =
    NotifierProvider<ZenTaoBugTabController, ZenTaoBugBrowseType>(
      ZenTaoBugTabController.new,
    );

/// The active bug tab's server slice: the ids of the bugs ZenTao returns for the
/// selected product + [zentaoBugTabProvider] browse type. Refetched on every tab
/// switch (autoDispose + reactive deps), and upserts those bugs into drift so
/// the board still renders from the DB (local-first). Empty off a product board.
final zentaoBugTabSliceProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final product = ref.watch(selectedZenTaoProductProvider);
  if (product == null) return const <String>{};
  final tab = ref.watch(zentaoBugTabProvider);
  final res = await ref
      .watch(sourceSyncServiceProvider)
      .syncProductBugsTab(
        accountId: product.accountId,
        productId: product.productId,
        browseType: tab.code,
      );
  switch (res) {
    case Ok(:final value):
      return value.toSet();
    case Err(:final failure):
      throw failure;
  }
});

class ZenTaoExecutionSelection {
  const ZenTaoExecutionSelection({
    required this.accountId,
    required this.projectId,
    required this.executionId,
    required this.executionName,
  });

  final String accountId;
  final String projectId;
  final String executionId;
  final String executionName;
}

class ZenTaoExecutionSyncing extends Notifier<String?> {
  @override
  String? build() => null;

  void start(ProviderExecution execution) =>
      state = '${execution.accountId}:${execution.id}';
  void finish() => state = null;
}

final zentaoExecutionSyncingProvider =
    NotifierProvider<ZenTaoExecutionSyncing, String?>(
      ZenTaoExecutionSyncing.new,
    );

class SelectedZenTaoExecution extends Notifier<ZenTaoExecutionSelection?> {
  @override
  ZenTaoExecutionSelection? build() => null;

  void select(ProviderExecution execution) {
    state = ZenTaoExecutionSelection(
      accountId: execution.accountId,
      projectId: execution.projectId,
      executionId: execution.id,
      executionName: execution.name,
    );
  }

  void clear() => state = null;
}

final selectedZenTaoExecutionProvider =
    NotifierProvider<SelectedZenTaoExecution, ZenTaoExecutionSelection?>(
      SelectedZenTaoExecution.new,
    );

/// Which ZenTao accounts have their collapsible "Executions" group expanded.
/// Empty by default, so every group starts collapsed.
class ZenTaoExecutionsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String accountId) {
    final next = Set<String>.of(state);
    next.contains(accountId) ? next.remove(accountId) : next.add(accountId);
    state = next;
  }
}

final zentaoExecutionsExpandedProvider =
    NotifierProvider<ZenTaoExecutionsExpanded, Set<String>>(
      ZenTaoExecutionsExpanded.new,
    );

/// Which ZenTao projects (`accountId:projectId`) have their execution list
/// expanded in the sidebar's Executions tree. Collapsed by default.
class ZenTaoExecutionProjectsExpanded extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final next = Set<String>.of(state);
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }
}

final zentaoExecutionProjectsExpandedProvider =
    NotifierProvider<ZenTaoExecutionProjectsExpanded, Set<String>>(
      ZenTaoExecutionProjectsExpanded.new,
    );

final zentaoProductsProvider =
    FutureProvider.family<List<ProviderProduct>, String>((
      ref,
      accountId,
    ) async {
      final res = await ref
          .watch(sourceSyncServiceProvider)
          .listProducts(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

final zentaoProjectsProvider =
    FutureProvider.family<List<ProviderProject>, String>((
      ref,
      accountId,
    ) async {
      final res = await ref
          .watch(sourceSyncServiceProvider)
          .listProjects(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

/// The connected ZenTao user's account handle (login) for [accountId] — the exact
/// value `Ticket.assignee` normalizes to (see `accountHandle` in the ZenTao
/// normalizer) — used as the default "my tickets" board filter. Empty when
/// unknown, in which case the board opens unfiltered.
final zentaoSelfHandleProvider = Provider.family<String, String>((
  ref,
  accountId,
) {
  return ref.watch(lookupsProvider).accounts[accountId]?.handle ?? '';
});

typedef ZenTaoExecutionsKey = ({String accountId, String projectId});

final zentaoExecutionsProvider =
    FutureProvider.family<List<ProviderExecution>, ZenTaoExecutionsKey>((
      ref,
      key,
    ) async {
      final res = await ref
          .watch(sourceSyncServiceProvider)
          .listProjectExecutions(key.accountId, key.projectId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });
