import '../navigation/app_nav_state.dart';

/// Interface for persisting and restoring the user's active navigation location.
abstract interface class NavLocationStore {
  /// Loads the persisted location. Returns null if none was stored or if the
  /// payload could not be decoded.
  Future<NavLocationPayload?> load();

  /// Schedules saving [payload] to disk (debounced by 500ms).
  void save(NavLocationPayload payload);

  /// Flushes any pending write immediately.
  Future<void> flush();

  /// Cancels any pending timers and releases resources.
  void dispose();
}
