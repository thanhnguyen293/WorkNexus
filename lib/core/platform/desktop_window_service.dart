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

  static WindowOptions windowOptionsFor({required bool isWindows}) {
    return WindowOptions(
      size: const Size(1440, 900),
      minimumSize: const Size(1040, 640),
      center: true,
      backgroundColor: const Color(0x00000000),
      skipTaskbar: false,
      title: appWindowTitle,
      titleBarStyle: isWindows ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
  }
}
