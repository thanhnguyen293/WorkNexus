import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/paged_view_loads.dart';

/// A paged board's cached tickets and what its views have loaded.
class PagedViewScopeQuery<V> {
  const PagedViewScopeQuery({
    required this.tickets,
    required this.loads,
    required this.viewOf,
    Object? Function(Ticket ticket)? columnOf,
  }) : columnOf = columnOf ?? viewOf;

  /// The board's tickets in the local database (already scoped to its
  /// account, type and product/execution).
  final List<Ticket> tickets;
  final PagedViewLoads<V> loads;

  /// The view a ticket's column draws on.
  final V Function(Ticket ticket) viewOf;

  /// The column a ticket sits in, where several columns share one view
  /// (Resolved, Postponed and Non-Fix all draw on `toclosed`); the view
  /// itself otherwise.
  final Object? Function(Ticket ticket) columnOf;
}

/// The tickets a paged board shows, local-first: a ticket a view has loaded
/// this session, or — for a view that has not loaded yet (still loading,
/// failed, offline, or not asked for) — whatever the database holds for it.
///
/// Once a view loads, it prunes the cached tickets the server no longer lists
/// there: all of them once every page is in, and while pages are left, those
/// of each column the loaded pages already reach. A column the loaded pages
/// have not reached yet keeps its cached tickets — one filled from the end of
/// a shared view (Non-Fix after Resolved) would otherwise lose its cards on
/// every refresh until it scrolled that far.
class ScopePagedViewTickets<V>
    extends UseCase<List<Ticket>, PagedViewScopeQuery<V>> {
  const ScopePagedViewTickets();

  @override
  List<Ticket> call(PagedViewScopeQuery<V> q) {
    final loaded = {for (final ids in q.loads.ids.values) ...?ids};
    final unloaded = {
      for (final MapEntry(:key, :value) in q.loads.ids.entries)
        if (value == null) key,
    };
    // The columns of each partial view that its loaded pages reach.
    final reached = <V, Set<Object?>>{};
    for (final t in q.tickets) {
      final view = q.viewOf(t);
      if (loaded.contains(t.id) && q.loads.partial.contains(view)) {
        (reached[view] ??= {}).add(q.columnOf(t));
      }
    }
    bool keepsCached(Ticket t) {
      final view = q.viewOf(t);
      if (unloaded.contains(view)) return true;
      return q.loads.partial.contains(view) &&
          !(reached[view]?.contains(q.columnOf(t)) ?? false);
    }

    return [
      for (final t in q.tickets)
        if (loaded.contains(t.id) || keepsCached(t)) t,
    ];
  }
}
