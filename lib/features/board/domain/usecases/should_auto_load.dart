import '../../../../core/usecase/usecase.dart';
import '../entities/paged_view_state.dart';
import '../value_objects/paging_policy.dart';

/// A column of a paged view, as its end comes into reach.
class AutoLoadQuery {
  const AutoLoadQuery({
    required this.state,
    required this.filtered,
    required this.visible,
  });

  final PagedViewState state;

  /// Whether the board's filter can hide loaded cards.
  final bool filtered;

  /// How many of the view's cards the board shows.
  final int visible;
}

/// Whether a column should fetch its view's next pages by itself. Unfiltered
/// it always does; under a filter only while recent loads keep turning up
/// cards — after [kMaxDryLoads] dry loads it offers "Load more" instead.
class ShouldAutoLoad extends UseCase<bool, AutoLoadQuery> {
  const ShouldAutoLoad();

  @override
  bool call(AutoLoadQuery q) =>
      q.state.canLoadMore &&
      (!q.filtered ||
          q.visible != q.state.scanVisible ||
          q.state.dryLoads < kMaxDryLoads);
}
