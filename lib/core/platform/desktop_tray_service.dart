import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../l10n/app_localizations.dart';
import '../debug/app_talker.dart';

/// Owns the native tray icon and translates its events into app actions.
class DesktopTrayService with TrayListener {
  static const _openKey = 'open_app';
  static const _quitKey = 'quit_app';

  Future<void> Function()? _onOpen;
  Future<void> Function()? _onQuit;
  bool _ready = false;

  Future<bool> initialize({
    required Locale locale,
    required Future<void> Function() onOpen,
    required Future<void> Function() onQuit,
  }) async {
    if (!(Platform.isWindows || Platform.isMacOS)) return false;
    _onOpen = onOpen;
    _onQuit = onQuit;
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/tray/app_icon.ico'
            : 'assets/tray/app_icon.png',
      );
      await trayManager.setToolTip('WorkNexus');
      await updateLocale(locale);
      _ready = true;
      return true;
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: initialize failed');
      await dispose();
      return false;
    }
  }

  Future<void> updateLocale(Locale locale) async {
    if (!(Platform.isWindows || Platform.isMacOS)) return;
    try {
      final strings = lookupAppL10n(locale);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _openKey, label: strings.trayOpenApp),
            MenuItem.separator(),
            MenuItem(key: _quitKey, label: strings.trayQuitApp),
          ],
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_ready) rethrow;
      appTalker.handle(error, stackTrace, 'Tray: menu update failed');
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (!_ready) return;
    if (Platform.isWindows) {
      final action = _onOpen;
      if (action != null) unawaited(_runAction(action));
    } else {
      unawaited(_showMenu());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_ready) unawaited(_showMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = switch (menuItem.key) {
      _openKey => _onOpen,
      _quitKey => _onQuit,
      _ => null,
    };
    if (action != null) unawaited(_runAction(action));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: action failed');
    }
  }

  Future<void> _showMenu() async {
    try {
      await trayManager.popUpContextMenu();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: menu failed');
    }
  }

  Future<void> dispose() async {
    _ready = false;
    _onOpen = null;
    _onQuit = null;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'Tray: dispose failed');
    }
  }
}
