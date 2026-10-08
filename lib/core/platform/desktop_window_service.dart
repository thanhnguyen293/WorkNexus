import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Thin seam over `window_manager` so the rest of the app never imports it
/// directly (mobile/web builds can provide a no-op implementation).
class DesktopWindowService {
  const DesktopWindowService();

  static const appWindowTitle = 'WorkNexus';

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Hides the native title bar and shows a centered window. Safe no-op off desktop.
  Future<void> initialize() async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    final options = windowOptionsFor(isWindows: Platform.isWindows);
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
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
    await windowManager.focus();
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
      titleBarStyle: isWindows ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
  }
}
