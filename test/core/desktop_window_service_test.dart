import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:work_nexus/core/platform/desktop_window_service.dart';

void main() {
  test('Windows uses the native title bar and WorkNexus window title', () {
    final options = DesktopWindowService.windowOptionsFor(isWindows: true);

    expect(options.title, 'WorkNexus');
    expect(options.titleBarStyle, TitleBarStyle.normal);
    expect(options.windowButtonVisibility, isTrue);
  });

  test('macOS keeps the custom hidden title bar', () {
    final options = DesktopWindowService.windowOptionsFor(isWindows: false);

    expect(options.title, 'WorkNexus');
    expect(options.titleBarStyle, TitleBarStyle.hidden);
    expect(options.windowButtonVisibility, isTrue);
  });
}
