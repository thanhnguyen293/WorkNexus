import 'dart:io';

import 'package:windows_single_instance/windows_single_instance.dart';

import 'desktop_window_service.dart';

/// Redirects a second Windows launch to the window owned by the first process.
class DesktopSingleInstanceService {
  const DesktopSingleInstanceService();

  Future<void> initialize(
    List<String> arguments,
    DesktopWindowService window,
  ) async {
    if (!Platform.isWindows) return;
    await WindowsSingleInstance.ensureSingleInstance(
      arguments,
      'worknexus',
      bringWindowToFront: false,
      onSecondWindow: (_) => window.bringToFront(),
    );
  }
}
