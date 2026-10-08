import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/filter_state.dart';

part 'saved_filter.freezed.dart';

/// A user-named filter preset — the board's "Save filter". Presets are global
/// (not tied to one board) so a filter set up on one product can be reapplied
/// wherever it makes sense; applying one that matches nothing is the user's
/// call, the same as picking the chips by hand.
@freezed
abstract class SavedFilter with _$SavedFilter {
  const factory SavedFilter({
    required String id,
    required String name,
    required FilterState filter,
    required DateTime createdAt,
  }) = _SavedFilter;
}
