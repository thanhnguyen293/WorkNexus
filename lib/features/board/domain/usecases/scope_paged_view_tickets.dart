import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/paged_view_loads.dart';

/// A paged board's cached tickets and what its views have loaded.
class PagedViewScopeQuery<V> {
  const PagedViewScopeQuery({
    required this.tickets,
    required this.loads,
    required this.viewOf,
  });

  /// The board's tickets in the local database (already scoped to its
  /// account, type and product/execution).
  final List<Ticket> tickets;
  final PagedViewLoads<V> loads;

  /// The view a ticket's column draws on.
  final V Function(Ticket ticket) viewOf;
}

/// The tickets a paged board shows, local-first: a ticket a view has loaded
/// this session, or — for a view that has not loaded yet (still loading,
/// failed, offline, or not asked for) — whatever the database holds for it.
/// Once a view has loaded every page, it prunes the cached tickets the server
/// no longer lists there. While it has pages left it cannot tell a ticket the
/// server dropped from one on a later page, so it keeps the cached ones — a
/// column filled from the end of a shared view (Non-Fix among Resolved) would
/// otherwise lose its cards on every refresh until it scrolled that far.
class ScopePagedViewTickets<V>
    extends UseCase<List<Ticket>, PagedViewScopeQuery<V>> {
  const ScopePagedViewTickets();

  @override
  List<Ticket> call(PagedViewScopeQuery<V> q) {
    final loaded = {for (final ids in q.loads.ids.values) ...?ids};
    final cachedViews = {
      for (final MapEntry(:key, :value) in q.loads.ids.entries)
        if (value == null) key,
      ...q.loads.partial,
    };
    return [
      for (final t in q.tickets)
        if (loaded.contains(t.id) || cachedViews.contains(q.viewOf(t))) t,
    ];
  }
}
