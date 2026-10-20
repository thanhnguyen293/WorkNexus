import 'package:flutter/foundation.dart';

/// What the app asks of a mini app's page, whichever web view shows it:
/// flutter_inappwebview on Windows and macOS, WebKitGTK on Linux.
abstract interface class MiniAppPageDriver {
  void load(String url);

  void reload();

  /// A reload that skips the cache.
  void hardReload();

  void stop();

  void goBack();

  void goForward();

  void openDevTools();

  Future<bool> canGoBack();

  Future<bool> canGoForward();

  /// Sets the page's `prefers-color-scheme`, for a web view that does not
  /// take the app window's look on its own.
  Future<void> setColorScheme(Brightness brightness);

  /// Stops the page while it is off screen, or lets it run again.
  Future<void> setSuspended(bool suspended);

  /// Caps how often the page draws; 0 lifts the cap.
  Future<void> setFrameRateLimit(int framesPerSecond);
}
