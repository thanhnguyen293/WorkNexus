import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/adapters/zentao_ticket_service.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';

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

class ZenTaoProductSelection {
  const ZenTaoProductSelection({
    required this.accountId,
    required this.productId,
    required this.productName,
  });

  final String accountId;
  final String productId;
  final String productName;
}

class SelectedZenTaoProduct extends Notifier<ZenTaoProductSelection?> {
  @override
  ZenTaoProductSelection? build() => null;

  /// Opens [product]'s bug board; the one already open stays as it is, so its
  /// loaded pages are kept (the toolbar's Refresh starts it over).
  void select(ProviderProduct product) {
    if (state?.accountId == product.accountId &&
        state?.productId == product.id) {
      return;
    }
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

/// Whether the bug board is on the Assigned-to-me tab, whose one server view
/// feeds every column (see [ZenTaoBugStream.of]).
final zentaoBugMineProvider = Provider<bool>(
  (ref) => ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.assignedToMe,
);

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

class SelectedZenTaoExecution extends Notifier<ZenTaoExecutionSelection?> {
  @override
  ZenTaoExecutionSelection? build() => null;

  /// Opens [execution]'s task board; the one already open stays as it is, so
  /// its loaded pages are kept (the toolbar's Refresh starts it over).
  void select(ProviderExecution execution) {
    if (state?.accountId == execution.accountId &&
        state?.executionId == execution.id) {
      return;
    }
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

/// Which ZenTao Project Sets (`accountId:groupId`) are collapsed in the
/// sidebar. Empty by default, so all Project Sets start expanded.
class ZenTaoProjectSetsCollapsed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final next = Set<String>.of(state);
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }
}

final zentaoProjectSetsCollapsedProvider =
    NotifierProvider<ZenTaoProjectSetsCollapsed, Set<String>>(
      ZenTaoProjectSetsCollapsed.new,
    );

/// Which ZenTao Product Sets (`accountId:groupId`) are collapsed in the
/// sidebar. Empty by default, so all Product Sets start expanded.
class ZenTaoProductSetsCollapsed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final next = Set<String>.of(state);
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }
}

final zentaoProductSetsCollapsedProvider =
    NotifierProvider<ZenTaoProductSetsCollapsed, Set<String>>(
      ZenTaoProductSetsCollapsed.new,
    );

Stream<List<T>> _cachedThenFresh<T>(
  Future<List<T>?> cached,
  Future<Result<List<T>>> Function() fetch,
) async* {
  final stored = await cached;
  if (stored != null) yield stored;
  switch (await fetch()) {
    case Ok(:final value):
      yield value;
    case Err(:final failure):
      if (stored == null) throw failure;
  }
}

final zentaoProductsProvider =
    StreamProvider.family<List<ProviderProduct>, String>(
      (ref, accountId) => _cachedThenFresh(
        getIt<ZenTaoTicketService>().cachedProducts(accountId),
        () => getIt<ZenTaoTicketService>().listProducts(accountId),
      ),
    );

final zentaoProjectsProvider =
    StreamProvider.family<List<ProviderProject>, String>(
      (ref, accountId) => _cachedThenFresh(
        getIt<ZenTaoTicketService>().cachedProjects(accountId),
        () => getIt<ZenTaoTicketService>().listProjects(accountId),
      ),
    );

typedef ZenTaoExecutionsKey = ({String accountId, String projectId});

final zentaoExecutionsProvider =
    FutureProvider.family<List<ProviderExecution>, ZenTaoExecutionsKey>((
      ref,
      key,
    ) async {
      final res = await getIt<ZenTaoTicketService>().listProjectExecutions(
        key.accountId,
        key.projectId,
      );
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

final zentaoBugBoardProvider = Provider<ZenTaoBugBoardModel>(
  (ref) => BuildZenTaoBugBoard(
    includeClosed: ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all,
  )(ref.watch(boardQueryProvider)),
);

class ZenTaoTaskDueThisWeekNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final zentaoTaskDueThisWeekProvider =
    NotifierProvider<ZenTaoTaskDueThisWeekNotifier, bool>(
      ZenTaoTaskDueThisWeekNotifier.new,
    );

final zentaoTaskBoardProvider = Provider<ZenTaoTaskBoardModel>(
  (ref) => BuildZenTaoTaskBoard(
    dueThisWeekOnly: ref.watch(zentaoTaskDueThisWeekProvider),
  )(ref.watch(boardQueryProvider)),
);
