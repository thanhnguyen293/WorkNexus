import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The message list's row widgets, kept between its builds.
///
/// Every change to the list (a new message, a typing peer, a scroll flag)
/// builds a new delegate, and the sliver asks it again for every row it has
/// laid out — dozens with the list's cache extent. Handing back the very
/// same widget for a row whose inputs did not change lets the framework stop
/// there instead of rebuilding the bubble and everything in it.
///
/// Keep it in the list's state; [clear] it when the list shows another chat.
class MessageRowCache {
  final _rows = <Object, ({List<Object?> inputs, Widget widget})>{};

  /// The widget last built for [key], while each of [inputs] still equals
  /// what it was built from; otherwise a new one from [build].
  Widget row(Object key, List<Object?> inputs, Widget Function() build) {
    final kept = _rows[key];
    if (kept != null && listEquals(kept.inputs, inputs)) return kept.widget;
    final widget = build();
    _rows[key] = (inputs: inputs, widget: widget);
    return widget;
  }

  /// Forgets the rows not in [keys] (scrolled out of the loaded pages).
  void retain(Set<Object> keys) =>
      _rows.removeWhere((key, _) => !keys.contains(key));

  void clear() => _rows.clear();
}
