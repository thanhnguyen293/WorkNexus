import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the elements an action rebuilds: the ones marked dirty (state,
/// provider or inherited changes) plus the ones handed a new widget by their
/// parent. Debug builds only — it is a test measurement.
class RebuildCounter {
  RebuildCounter(this.tester);

  final WidgetTester tester;
  Map<Element, Widget> _before = const {};
  int _dirty = 0;

  void start() {
    _before = {for (final e in tester.allElements) e: e.widget};
    _dirty = 0;
    debugOnRebuildDirtyWidget = (_, _) => _dirty++;
  }

  /// Rebuilt elements since [start], all or only those whose widget is [T].
  int stop<T extends Widget>() {
    debugOnRebuildDirtyWidget = null;
    var changed = 0;
    for (final e in tester.allElements) {
      if (e.widget is! T) continue;
      if (!identical(_before[e], e.widget)) changed++;
    }
    return T == Widget ? changed + _dirty : changed;
  }
}
