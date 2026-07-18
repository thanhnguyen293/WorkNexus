import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/result.dart';
import '../domain/entities/board_model.dart';
import '../domain/entities/filter_state.dart';
import '../domain/usecases/build_board.dart';
import '../domain/usecases/build_list.dart';
import '../domain/usecases/build_zentao_bug_board.dart';
import '../domain/usecases/build_zentao_task_board.dart';
import '../domain/usecases/filter_tickets.dart';
import '../domain/value_objects/saved_view.dart';

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

  void clearAll() => state = state.copyWith(
    providers: {},
    accountIds: {},
    projectIds: {},
    statuses: {},
    priorities: {},
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

class ZenTaoProductSyncing extends Notifier<String?> {
  @override
  String? build() => null;

  void start(ProviderProduct product) =>
      state = '${product.accountId}:${product.id}';
  void finish() => state = null;
}

final zentaoProductSyncingProvider =
    NotifierProvider<ZenTaoProductSyncing, String?>(ZenTaoProductSyncing.new);

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

final zentaoProductsProvider =
    FutureProvider.family<List<ProviderProduct>, String>((
      ref,
      accountId,
    ) async {
      final res = await ref.watch(syncServiceProvider).listProducts(accountId);
      switch (res) {
        case Ok(:final value):
          return value;
        case Err(:final failure):
          throw failure;
      }
    });

/// The query fed to the pure board/list use cases.
final _boardQueryProvider = Provider<BoardQuery>((ref) {
  var tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  final product = ref.watch(selectedZenTaoProductProvider);
  if (product != null) {
    final productLabel = 'zentao-product:${product.productId}';
    tickets = tickets
        .where(
          (ticket) =>
              ticket.accountId == product.accountId &&
              (ticket.externalType ?? '').toLowerCase() == 'bug' &&
              ticket.labels.contains(productLabel),
        )
        .toList();
  }
  final filter = ref.watch(filterStateProvider);
  return BoardQuery(
    tickets: tickets,
    filter: filter,
    accountWorkspace: ref.watch(accountWorkspaceProvider),
    workspaceOrder: ref.watch(workspaceOrderProvider),
    now: DateTime.now(),
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
