import 'dart:io';

/// The `.AppImage` file this process was started from, or null when it runs
/// from an unpacked bundle. The AppImage runtime sets `APPIMAGE`; the binary
/// itself runs from a mount that is gone once the app exits, so anything that
/// must outlive the process (the desktop entry, an update) points here.
String? runningAppImage() {
  final path = Platform.environment['APPIMAGE'];
  return path == null || path.isEmpty ? null : path;
}
