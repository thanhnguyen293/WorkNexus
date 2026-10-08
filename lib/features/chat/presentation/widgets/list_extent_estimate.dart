import 'dart:math' as math;

/// Running estimate of a lazy list's scroll extent, built from every row laid
/// out so far rather than only the rows currently on screen.
///
/// A `ListView.builder` guesses the length of what it has not laid out from
/// the average height of the rows it has (viewport plus cache). With rows
/// ranging from one text line to a full image, that average changes every
/// frame, and the scrollbar thumb jumps with it. Here the average covers all
/// rows from the first to the furthest ever laid out, so it only moves when
/// new rows are reached, and stays put when scrolling back over known ones.
///
/// Row offsets are measured from the start of the list (row 0), so the end
/// offset of row `n` is the exact height of rows `0..n`.
class ListExtentEstimate {
  /// Rows `0.._rows - 1` have been laid out; [_extent] is their total height.
  int _rows = 0;
  double _extent = 0;

  /// Forgets everything, for a list whose rows changed wholesale.
  void reset() {
    _rows = 0;
    _extent = 0;
  }

  /// The estimated end of the list, given the furthest row laid out this
  /// frame ([lastIndex]), where it ends ([trailingScrollOffset]) and how many
  /// rows the list has in all ([childCount]).
  double maxScrollOffset({
    required int lastIndex,
    required double trailingScrollOffset,
    required int childCount,
  }) {
    // Reached further than before (or rows were removed): the fresh
    // measurement becomes the known region.
    if (lastIndex + 1 >= _rows || _rows > childCount) {
      _rows = lastIndex + 1;
      _extent = trailingScrollOffset;
    }
    final estimate = _extent + (_extent / _rows) * (childCount - _rows);
    // Known rows may have grown since they were measured: never report an
    // end before what is laid out right now.
    return math.max(estimate, trailingScrollOffset);
  }
}
