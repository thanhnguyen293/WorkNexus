import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../domain/entities/board_model.dart';
import '../domain/entities/filter_state.dart';
import '../domain/usecases/build_board.dart';
import '../domain/usecases/build_list.dart';
import '../domain/usecases/build_zentao_bug_board.dart';
import '../domain/usecases/build_zentao_task_board.dart';
import '../domain/usecases/filter_tickets.dart';
import '../domain/value_objects/saved_view.dart';

enum ViewMode { board, zentaoBugs, zentaoTasks, list }

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

/// The query fed to the pure board/list use cases.
final _boardQueryProvider = Provider<BoardQuery>((ref) {
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
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
