import 'dart:async';

import 'package:window_manager/window_manager.dart';

import 'window_placement_store.dart';

/// Saves whether the window is maximized each time that changes, so the next
/// launch opens it the same way. Full screen is left out: it is entered for a
/// video, not as a way of using the app.
class WindowPlacementRecorder with WindowListener {
  WindowPlacementRecorder(this._store);

  final WindowPlacementStore _store;

  @override
  void onWindowMaximize() => unawaited(_store.writeMaximized(true));

  @override
  void onWindowUnmaximize() => unawaited(_store.writeMaximized(false));
}
