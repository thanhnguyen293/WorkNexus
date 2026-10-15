import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/usecases/switch_board_filter.dart';
import '../../domain/value_objects/saved_view.dart';
import 'board_loading_provider.dart';

class CustomBoardKeyController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? k) => state = k;
}

final customBoardKeyProvider =
    NotifierProvider<CustomBoardKeyController, String?>(
      CustomBoardKeyController.new,
    );

/// A stable identity for the board on screen — the key its filter is remembered
/// under by [FilterController.openBoard].
final boardKeyProvider = Provider<String>((ref) {
  final custom = ref.watch(customBoardKeyProvider);
  if (custom != null) return custom;
  final section = ref.watch(
    appNavProvider.select((s) => s.currentLocation?.section.value),
  );
  return section ?? 'default';
});

/// Active filter selection + intent methods (the design's filter interactions).
///
/// Also owns the per-board filter memory: see [openBoard]. The memory lives for
/// the session only — durable selections are what the saved presets
/// (`SavedFilter`) are for.
class FilterController extends Notifier<FilterState> {
  /// The filter each visited board was left with, keyed by `boardKeyProvider`
  /// (defined in `board_providers.dart`, which re-exports this file).
  final Map<String, FilterState> _memory = <String, FilterState>{};

  /// The board [state] currently belongs to; null before the first board opens.
  String? _activeKey;

  @override
  FilterState build() {
    ref.listen<String>(boardKeyProvider, (prev, next) {
      if (prev != next) {
        openBoard(next);
      }
    });
    final initialKey = ref.read(boardKeyProvider);
    _activeKey = initialKey;
    return _initialFor(initialKey);
  }

  FilterState _initialFor(String key, [FilterState? current]) {
    final isZenTao =
        key == 'zentao.tasks' ||
        key == 'zentao.bugs' ||
        key.startsWith('zentao.');
    final base = current != null ? _cleared(current) : const FilterState();
    return isZenTao ? base.copyWith(savedView: SavedView.mine) : base;
  }

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
  void toggleReviewer(String r) =>
      state = state.copyWith(reviewers: _toggle(state.reviewers, r));
  void toggleBugType(String t) =>
      state = state.copyWith(bugTypes: _toggle(state.bugTypes, t));
  void toggleResolution(String r) =>
      state = state.copyWith(resolutions: _toggle(state.resolutions, r));

  void toggleZenTaoStatus(String s) =>
      state = state.copyWith(zentaoStatuses: _toggle(state.zentaoStatuses, s));
  void toggleResolver(String r) =>
      state = state.copyWith(resolvers: _toggle(state.resolvers, r));
  void toggleReporter(String r) =>
      state = state.copyWith(reporters: _toggle(state.reporters, r));
  void toggleConfirmation(String c) =>
      state = state.copyWith(confirmations: _toggle(state.confirmations, c));

  void clearAll() => state = _cleared(state);

  /// Switches the board filter to the board identified by [key] (see
  /// `boardKeyProvider`), filing the current board's filter away first.
  ///
  /// Boards used to wipe the filter on every switch, so glancing at another
  /// project cost you a filter you had just built. Now each board keeps its own:
  /// returning restores what you left, and only a board's *first* visit gets the
  /// default: no chip filters.
  void openBoard(String key) {
    final next = const SwitchBoardFilter()(
      memory: _memory,
      fromKey: _activeKey,
      toKey: key,
      current: state,
      initial: _initialFor(key, state),
    );
    _memory
      ..clear()
      ..addAll(next.memory);
    _activeKey = key;
    state = next.filter;
  }

  /// Replaces the chip filters with a saved preset's, keeping the board's own
  /// workspace scope (a preset is a set of criteria, not a place to go).
  void applyPreset(FilterState preset) =>
      state = preset.copyWith(workspaceId: state.workspaceId);

  /// Everything cleared except the board's scope ([FilterState.workspaceId]).
  FilterState _cleared(FilterState from) => from.copyWith(
    providers: {},
    accountIds: {},
    projectIds: {},
    statuses: {},
    priorities: {},
    severities: {},
    assignees: {},
    reviewers: {},
    bugTypes: {},
    resolutions: {},
    zentaoStatuses: {},
    resolvers: {},
    reporters: {},
    confirmations: {},
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
