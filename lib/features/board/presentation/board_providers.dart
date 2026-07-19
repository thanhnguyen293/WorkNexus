import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/result.dart';
import '../../sync/data/sync_service.dart';
import '../domain/entities/board_model.dart';
import '../domain/entities/filter_state.dart';
import '../domain/usecases/build_board.dart';
import '../domain/usecases/build_list.dart';
import '../domain/usecases/build_zentao_bug_board.dart';
import '../domain/usecases/build_zentao_task_board.dart';
import '../domain/usecases/derive_board_facets.dart';
import '../domain/usecases/filter_tickets.dart';
import '../domain/value_objects/saved_view.dart';
import '../domain/value_objects/zentao_bug_browse_type.dart';

enum ViewMode { board, zentaoBugs, zentaoTasks, list }

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

final viewModeProvider = NotifierProvider<ViewModeController, ViewMode>(
  ViewModeController.new,
);

class ViewModeController extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.board;
  void set(ViewMode m) => state = m;
}

/// Active filter selection + intent methods (the design's filter interactions).
class FilterController extends Notifier<FilterState> {
  @override
  FilterState build() => const FilterState();

  void setWorkspace(String id) {
    state = state.copyWith(workspaceId: id, accountIds: {}, projectIds: {});
    ref.read(boardLoadingProvider.notifier).pulse();
  }

  void setSavedView(SavedView v) => state = state.copyWith(savedView: v);
  void setSearch(String q) => state = state.copyWith(search: q);

  void toggleProvider(ProviderType p) =>
      state = state.copyWith(providers: _toggle(state.providers, p));
  void toggleAccount(String id) =>
      state = state.copyWith(accountIds: _toggle(state.accountIds, id));
  void toggleProject(String id) =>
      state = state.copyWith(projectIds: _toggle(state.projectIds, id));
  void toggleStatus(UnifiedStatus s) =>
      state = state.copyWith(statuses: _toggle(state.statuses, s));
  void togglePriority(Priority p) =>
      state = state.copyWith(priorities: _toggle(state.priorities, p));
  void toggleSeverity(int s) =>
      state = state.copyWith(severities: _toggle(state.severities, s));
  void toggleAssignee(String a) =>
      state = state.copyWith(assignees: _toggle(state.assignees, a));
  void toggleBugType(String t) =>
      state = state.copyWith(bugTypes: _toggle(state.bugTypes, t));
  void toggleResolution(String r) =>
      state = state.copyWith(resolutions: _toggle(state.resolutions, r));

  void clearAll() => state = state.copyWith(
    providers: {},
    accountIds: {},
    projectIds: {},
    statuses: {},
    priorities: {},
    severities: {},
    assignees: {},
    bugTypes: {},
    resolutions: {},
    search: '',
  );

  Set<T> _toggle<T>(Set<T> set, T value) {
    final next = Set<T>.of(set);
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }
}

final filterStateProvider = NotifierProvider<FilterController, FilterState>(
  FilterController.new,
);

/// Brief skeleton state on first load and workspace switches (design parity).
class BoardLoading extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _schedule();
    return true;
  }

  void pulse() {
    state = true;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 480), () {
      if (ref.mounted) state = false;
    });
  }
}

final boardLoadingProvider = NotifierProvider<BoardLoading, bool>(
  BoardLoading.new,
);

class TicketActionPending extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void start(String id) => state = {...state, id};

  void finish(String id) {
    final next = {...state}..remove(id);
    state = next;
  }
}

final ticketActionPendingProvider =
    NotifierProvider<TicketActionPending, Set<String>>(TicketActionPending.new);

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
  final res = await getIt<SyncService>().syncProductBugsTab(
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
    required this.executionId,
    required this.executionName,
  });

  final String accountId;
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
      final res = await getIt<SyncService>().listProducts(accountId);
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
      final res = await getIt<SyncService>().listProjects(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

typedef ZenTaoExecutionsKey = ({String accountId, String projectId});

final zentaoExecutionsProvider =
    FutureProvider.family<List<ProviderExecution>, ZenTaoExecutionsKey>((
      ref,
      key,
    ) async {
      final res = await getIt<SyncService>().listProjectExecutions(
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

/// Tickets scoped to the active ZenTao product/execution selection, before the
/// user's chip filters. Facets are derived from this set so chip options and
/// counts stay stable while filters toggle.
final _scopedTicketsProvider = Provider<List<Ticket>>((ref) {
  var tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  final product = ref.watch(selectedZenTaoProductProvider);
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  if (execution != null) {
    final executionLabel = 'zentao-execution:${execution.executionId}';
    tickets = tickets
        .where(
          (ticket) =>
              ticket.accountId == execution.accountId &&
              (ticket.externalType ?? '').toLowerCase() == 'task' &&
              ticket.labels.contains(executionLabel),
        )
        .toList();
  } else if (product != null) {
    final productLabel = 'zentao-product:${product.productId}';
    // The active bug tab's server slice (ids). Null while it's still loading —
    // show nothing until it resolves (the board page renders a skeleton) so a
    // tab switch never flashes the previous tab's bugs.
    final slice = ref.watch(zentaoBugTabSliceProvider).asData?.value;
    tickets = tickets
        .where(
          (ticket) =>
              ticket.accountId == product.accountId &&
              (ticket.externalType ?? '').toLowerCase() == 'bug' &&
              ticket.labels.contains(productLabel) &&
              slice != null &&
              slice.contains(ticket.id),
        )
        .toList();
  }
  return tickets;
});

/// The query fed to the pure board/list use cases.
final _boardQueryProvider = Provider<BoardQuery>((ref) {
  return BoardQuery(
    tickets: ref.watch(_scopedTicketsProvider),
    filter: ref.watch(filterStateProvider),
    accountWorkspace: ref.watch(accountWorkspaceProvider),
    workspaceOrder: ref.watch(workspaceOrderProvider),
    now: DateTime.now(),
  );
});

/// Available filter facets for the current ZenTao board (empty off-ZenTao).
final boardFacetsProvider = Provider<BoardFacets>((ref) {
  final scope = switch (ref.watch(viewModeProvider)) {
    ViewMode.zentaoBugs => BoardFacetScope.bug,
    ViewMode.zentaoTasks => BoardFacetScope.task,
    ViewMode.board || ViewMode.list => BoardFacetScope.none,
  };
  if (scope == BoardFacetScope.none) return BoardFacets.empty;
  return const DeriveBoardFacets()(
    BoardFacetsInput(tickets: ref.watch(_scopedTicketsProvider), scope: scope),
  );
});

final boardProvider = Provider<BoardModel>(
  (ref) => const BuildBoard()(ref.watch(_boardQueryProvider)),
);

final zentaoBugBoardProvider = Provider<ZenTaoBugBoardModel>(
  (ref) => const BuildZenTaoBugBoard()(ref.watch(_boardQueryProvider)),
);

final zentaoTaskBoardProvider = Provider<ZenTaoTaskBoardModel>(
  (ref) => const BuildZenTaoTaskBoard()(ref.watch(_boardQueryProvider)),
);

final listRowsProvider = Provider<List<Ticket>>(
  (ref) => const BuildList()(ref.watch(_boardQueryProvider)),
);

final resultCountProvider = Provider<int>((ref) {
  if (ref.watch(viewModeProvider) == ViewMode.zentaoBugs) {
    return ref.watch(zentaoBugBoardProvider).total;
  }
  if (ref.watch(viewModeProvider) == ViewMode.zentaoTasks) {
    return ref.watch(zentaoTaskBoardProvider).total;
  }
  final q = ref.watch(_boardQueryProvider);
  return const FilterTickets()(q).length;
});
