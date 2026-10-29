import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../domain/entities/board_model.dart';
import '../../domain/usecases/build_board.dart';
import '../../domain/usecases/derive_board_facets.dart';
import '../../domain/usecases/filter_tickets.dart';
import '../../domain/usecases/search_local_tickets.dart';
import 'filter_providers.dart';

export 'board_loading_provider.dart';
export 'filter_providers.dart';

/// The layout style for displaying task and bug collections:
/// - [kanban]: visual workflow columns with drag-and-drop cards.
/// - [table]: high-density structured table with columns for ID, Module, Delay, Priority, etc.
enum BoardViewStyle { kanban, table }

class BoardViewStyleController extends Notifier<BoardViewStyle> {
  @override
  BoardViewStyle build() => BoardViewStyle.kanban;

  void set(BoardViewStyle s) => state = s;
  void toggle() => state = state == BoardViewStyle.kanban
      ? BoardViewStyle.table
      : BoardViewStyle.kanban;
}

final boardViewStyleProvider =
    NotifierProvider<BoardViewStyleController, BoardViewStyle>(
      BoardViewStyleController.new,
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

class ScopedTicketsOverrideController extends Notifier<List<Ticket>?> {
  @override
  List<Ticket>? build() => null;
  void set(List<Ticket>? t) => state = t;
}

/// Provider allowing external callers / tools to override the scoped tickets.
final scopedTicketsOverrideProvider =
    NotifierProvider<ScopedTicketsOverrideController, List<Ticket>?>(
      ScopedTicketsOverrideController.new,
    );

class IsMineBoardController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final isMineBoardProvider = NotifierProvider<IsMineBoardController, bool>(
  IsMineBoardController.new,
);

class UsesFacetFiltersController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final usesFacetFiltersProvider =
    NotifierProvider<UsesFacetFiltersController, bool>(
      UsesFacetFiltersController.new,
    );

/// Incremented to signal that the active board streams/slices should refresh.
class BoardRefreshTrigger extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final boardRefreshTriggerProvider = NotifierProvider<BoardRefreshTrigger, int>(
  BoardRefreshTrigger.new,
);

/// Tickets scoped to the active board, before the user's chip filters.
final scopedTicketsProvider = Provider<List<Ticket>>((ref) {
  final override = ref.watch(scopedTicketsOverrideProvider);
  if (override != null) return override;
  final tickets = ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
  final nav = ref.watch(appNavProvider);
  final rail = nav.rail;
  final location = nav.currentLocation;
  if (rail is! AccountTarget || location == null) return tickets;
  final account = ref.watch(
    lookupsProvider.select((l) => l.accounts[rail.accountId]),
  );
  final module = account == null
      ? null
      : ref.watch(toolRegistryProvider)[account.providerType];
  return module?.scopeTickets(ref, location, tickets) ?? tickets;
});

/// The query fed to the pure board/list use cases.
final boardQueryProvider = Provider<BoardQuery>((ref) {
  return BoardQuery(
    tickets: ref.watch(scopedTicketsProvider),
    filter: ref.watch(filterStateProvider),
    accountWorkspace: ref.watch(accountWorkspaceProvider),
    workspaceOrder: ref.watch(workspaceOrderProvider),
    now: DateTime.now(),
    accounts: ref.watch(lookupsProvider).accounts,
  );
});

typedef GenericFilterScope = ({
  Set<ProviderType> providers,
  Set<String> accountIds,
  Set<String> projectIds,
});

final genericFilterScopeProvider = Provider<GenericFilterScope>((ref) {
  final tickets = ref.watch(scopedTicketsProvider);
  final providers = <ProviderType>{};
  final accountIds = <String>{};
  final projectIds = <String>{};
  for (final t in tickets) {
    providers.add(t.providerType);
    accountIds.add(t.accountId);
    projectIds.add(t.projectId);
  }
  return (providers: providers, accountIds: accountIds, projectIds: projectIds);
});

/// Which facet dimensions the section on screen is filtered by: the ZenTao bug
/// and task boards and the GitLab MR board have data-derived facets.
final boardFacetScopeProvider = Provider<BoardFacetScope>((ref) {
  final section = ref.watch(
    appNavProvider.select((s) => s.currentLocation?.section.value),
  );
  return switch (section) {
    'zentao.bugs' => BoardFacetScope.bug,
    'zentao.tasks' => BoardFacetScope.task,
    'gitlab.mrs' => BoardFacetScope.gitlabMergeRequest,
    _ => BoardFacetScope.none,
  };
});

final filterHasGroupsProvider = Provider<bool>((ref) {
  if (ref.watch(boardFacetScopeProvider) != BoardFacetScope.none) return true;
  return ref.watch(genericFilterScopeProvider).projectIds.length >= 2;
});

/// The facets of the board on screen, completed by its tool's catalog of
/// every choice when it has one (see [BoardFacetCatalog]).
final boardFacetsProvider = Provider.autoDispose
    .family<BoardFacets, BoardFacetCatalog?>((ref, catalog) {
      final scope = ref.watch(boardFacetScopeProvider);
      if (scope == BoardFacetScope.none) return BoardFacets.empty;
      return const DeriveBoardFacets()(
        BoardFacetsInput(
          tickets: ref.watch(scopedTicketsProvider),
          scope: scope,
          catalog: catalog,
        ),
      );
    });

final boardProvider = Provider<BoardModel>(
  (ref) => const BuildBoard()(ref.watch(boardQueryProvider)),
);

final resultCountProvider = Provider<int>((ref) {
  final q = ref.watch(boardQueryProvider);
  return const FilterTickets()(q).length;
});

/// Contextual search results provider (design §7, specs S2.3).
final contextualSearchResultsProvider =
    Provider.family<List<Ticket>, ({String query, String? accountId})>((
      ref,
      arg,
    ) {
      if (arg.query.trim().isEmpty) return const [];
      final tickets =
          ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
      return const SearchLocalTickets().call(
        SearchLocalTicketsInput(
          tickets: tickets,
          query: arg.query,
          accountId: arg.accountId,
        ),
      );
    });
