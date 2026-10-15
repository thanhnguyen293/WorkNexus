import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import 'window_placement_recorder.dart';
import 'window_placement_store.dart';

/// Thin seam over `window_manager` so the rest of the app never imports it
/// directly (mobile/web builds can provide a no-op implementation).
class DesktopWindowService {
  const DesktopWindowService();

  static const appWindowTitle = AppConfig.appName;

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get hasCustomCaptionButtons =>
      Platform.isWindows || Platform.isLinux;

  /// Whether the app draws its own minimize / maximize / close buttons. The
  /// hidden title bar takes the native ones away everywhere but macOS, which
  /// keeps its traffic lights.
  static bool get drawsCaptionButtons => Platform.isWindows || Platform.isLinux;

  /// Hides the native title bar and shows the window: maximized when it was
  /// maximized last time, otherwise centered at its default size. Safe no-op
  /// off desktop.
  ///
  /// A window already on screen is left where it is: on a hot restart the
  /// native window outlives the Dart side, and sizing a maximized window to
  /// the default would shrink the app inside its still-maximized frame.
  Future<void> initialize() async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    const store = WindowPlacementStore();
    if (await windowManager.isVisible()) {
      windowManager.addListener(WindowPlacementRecorder(store));
      return;
    }
    final maximized = await store.readMaximized();
    final options = windowOptionsFor(isWindows: Platform.isWindows);
    await windowManager.waitUntilReadyToShow(options, () async {
      if (maximized) await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(WindowPlacementRecorder(store));
  }

  /// Room to leave on the left of anything drawn at the very top of the
  /// window: macOS draws its traffic-light buttons there (hidden title bar).
  static double get windowButtonsInset => Platform.isMacOS ? 72 : 0;

  /// Enters or leaves full screen (e.g. for a video).
  Future<void> toggleFullScreen() async {
    if (!isDesktop) return;
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  }

  /// Leaves full screen if the window is in it.
  Future<void> exitFullScreen() async {
    if (!isDesktop) return;
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
  }

  /// Whether the app window has keyboard focus (true off desktop, where the
  /// app is either in front or not running).
  Future<bool> isFocused() async {
    if (!isDesktop) return true;
    return windowManager.isFocused();
  }

  /// Restores and focuses the window, e.g. after a notification click.
  Future<void> bringToFront() async {
    if (!isDesktop) return;
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    if (isWindows) {
      // Windows keeps a background process from taking the foreground
      // (SetForegroundWindow just flashes the taskbar button), so a window
      // hidden in the tray stayed behind after a toast click. Going topmost
      // for a moment lifts it above the others; then it is a normal window
      // again.
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(false);
      return;
    }
    await windowManager.focus();
  }

  Future<void> hide() async {
    if (!isDesktop) return;
    await windowManager.hide();
  }

  Future<void> preventClose(bool prevent) async {
    if (!isDesktop) return;
    await windowManager.setPreventClose(prevent);
  }

  void addListener(WindowListener listener) {
    if (isDesktop) windowManager.addListener(listener);
  }

  void removeListener(WindowListener listener) {
    if (isDesktop) windowManager.removeListener(listener);
  }

  /// Hides the window, then ends the process. Not `windowManager.destroy()`:
  /// on Windows that only stops the message loop, and the window stayed on
  /// screen, frozen, until the engine had shut down.
  Future<void> quit() async {
    if (!isDesktop) return;
    await windowManager.hide();
    exit(0);
  }

  static WindowOptions windowOptionsFor({required bool isWindows}) {
    return WindowOptions(
      size: const Size(1440, 900),
      // Narrow enough to sit beside other windows: the chat collapses its
      // list to avatars (nav rail + list + its 520px message column) and
      // the board scrolls sideways.
      minimumSize: const Size(680, 480),
      center: true,
      backgroundColor: const Color(0x00000000),
      skipTaskbar: false,
      title: appWindowTitle,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: !isWindows,
    );
  }
}
