import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/paged_view_state.dart';

part 'paged_view_loads.freezed.dart';

/// What a paged board's views have loaded, and nothing else of their state:
/// the ids a started view holds, or `null` for a view that has not loaded its
/// first page yet (still loading, failed, offline, or not asked for).
///
/// Compares by value, so a page starting, failing or being retried — which
/// changes the view's [PagedViewState] but not what is loaded — does not
/// re-scope the board.
@freezed
abstract class PagedViewLoads<V> with _$PagedViewLoads<V> {
  const factory PagedViewLoads(Map<V, Set<String>?> ids) = _PagedViewLoads<V>;

  /// Projects the views' states down to what each has loaded.
  factory PagedViewLoads.of(Map<V, PagedViewState> views) => PagedViewLoads({
    for (final MapEntry(:key, :value) in views.entries)
      key: value.started ? value.ids : null,
  });
}
