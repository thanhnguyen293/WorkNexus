import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/paged_view_state.dart';

/// A paged board's cached tickets and what its views have loaded.
class PagedViewScopeQuery<V> {
  const PagedViewScopeQuery({
    required this.tickets,
    required this.views,
    required this.viewOf,
  });

  /// The board's tickets in the local database (already scoped to its
  /// account, type and product/execution).
  final List<Ticket> tickets;
  final Map<V, PagedViewState> views;

  /// The view a ticket's column draws on.
  final V Function(Ticket ticket) viewOf;
}

/// The tickets a paged board shows, local-first: a ticket a view has loaded
/// this session, or — for a view that has not loaded yet (still loading,
/// failed, offline, or not asked for) — whatever the database holds for it.
/// Once a view loads, it prunes the cached tickets the server no longer lists
/// there.
class ScopePagedViewTickets<V>
    extends UseCase<List<Ticket>, PagedViewScopeQuery<V>> {
  const ScopePagedViewTickets();

  @override
  List<Ticket> call(PagedViewScopeQuery<V> q) {
    final loaded = {for (final s in q.views.values) ...s.ids};
    final unloaded = {
      for (final MapEntry(:key, :value) in q.views.entries)
        if (!value.started) key,
    };
    return [
      for (final t in q.tickets)
        if (loaded.contains(t.id) || unloaded.contains(q.viewOf(t))) t,
    ];
  }
}
