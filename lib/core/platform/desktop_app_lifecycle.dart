import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../debug/app_talker.dart';
import 'desktop_tray_service.dart';
import 'desktop_window_service.dart';

/// Coordinates native close events with the tray and the app window.
class DesktopAppLifecycle with WindowListener {
  DesktopAppLifecycle({
    required DesktopWindowService window,
    required DesktopTrayService tray,
  }) : _window = window,
       _tray = tray;

  final DesktopWindowService _window;
  final DesktopTrayService _tray;
  bool _trayReady = false;
  bool _quitting = false;

  Future<void> initialize(Locale locale) async {
    _trayReady = await _tray.initialize(
      locale: locale,
      onOpen: open,
      onQuit: quit,
    );
    if (!_trayReady) return;
    try {
      _window.addListener(this);
      await _window.preventClose(true);
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: close interception failed');
      _window.removeListener(this);
      _trayReady = false;
      await _tray.dispose();
    }
  }

  Future<void> updateLocale(Locale locale) async {
    if (_trayReady) await _tray.updateLocale(locale);
  }

  @override
  void onWindowClose() {
    if (_trayReady && !_quitting) {
      unawaited(_hide());
    }
  }

  Future<void> _hide() async {
    try {
      await _window.hide();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: hide failed');
    }
  }

  Future<void> open() => _window.bringToFront();

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    _window.removeListener(this);
    await _tray.dispose();
    await _window.quit();
  }
}
