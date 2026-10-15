import '../entities/filter_state.dart';

/// The outcome of moving the board filter from one board to another: the
/// updated per-board memory and the filter the new board opens with.
typedef BoardFilterSwitch = ({
  Map<String, FilterState> memory,
  FilterState filter,
});

/// Moves the active filter when the user opens another board.
///
/// Filters used to be wiped on every board switch, which meant losing a
/// carefully built selection just by glancing at another project. Instead each
/// board remembers its own filter: leaving a board files its filter under that
/// board's key, and returning restores it. A board seen for the first time
/// opens with [initial] — the caller's default (e.g. ZenTao's "my tickets").
///
/// Memory is per board rather than one sticky global filter on purpose: a
/// ZenTao assignee handle or bug severity carried onto a GitLab board matches
/// nothing and would silently empty it.
class SwitchBoardFilter {
  const SwitchBoardFilter();

  BoardFilterSwitch call({
    required Map<String, FilterState> memory,
    required String? fromKey,
    required String toKey,
    required FilterState current,
    required FilterState initial,
  }) {
    final next = Map<String, FilterState>.of(memory);
    if (fromKey != null) next[fromKey] = current;
    // Re-selecting the board you are already on is a no-op, not a reset.
    if (fromKey == toKey) return (memory: next, filter: current);
    return (memory: next, filter: next[toKey] ?? initial);
  }
}
