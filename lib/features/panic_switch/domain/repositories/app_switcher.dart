import '../../../../core/error/result.dart';
import '../entities/app_ref.dart';

/// Brings other apps to the front and hides them, through the OS.
abstract interface class AppSwitcher {
  /// Whether running apps can be raised and hidden here; false where the OS
  /// only lets an app be started (Linux on Wayland).
  bool get canRaiseApps;

  /// Apps the user can pick from: installed and running ones.
  Future<Result<List<AppRef>>> listApps();

  /// Brings [app] to the front, starting it when it is not running.
  Future<Result<void>> activate(AppRef app);

  /// Hides (or minimises) every running app but [keep] and WorkNexus.
  Future<Result<void>> hideOthers(List<AppRef> keep);

  /// Hides WorkNexus.
  Future<Result<void>> hideSelf();
}
