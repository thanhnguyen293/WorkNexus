import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../debug/app_talker.dart';

/// The name the user gave the app, shown in place of [AppConfig.appName]: the
/// window's title (taskbar button hover, Alt-Tab), the tray's tooltip and the
/// app's own title bar. Kept in a text file in the support folder.
///
/// What the executable carries (its file name, Task Manager, Start menu) and
/// the name on a system notification are fixed at build or install time, so
/// they keep the default.
class AppNameService {
  AppNameService({Future<File> Function()? file, this._setTrayToolTip})
    : _file = file ?? _supportFile;

  static bool get supported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// The longest name kept: a title bar shows little more.
  static const maxLength = 40;

  final Future<File> Function() _file;
  final Future<void> Function(String? name)? _setTrayToolTip;

  static Future<File> _supportFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/app_name.txt');

  /// The name the user gave, or null while the app has its own.
  Future<String?> current() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final name = (await file.readAsString()).trim();
    return name.isEmpty ? null : name;
  }

  /// Keeps [name] as the app's name (blank gives the own name back). False
  /// when it could not be kept; the name in use stays as it was.
  Future<bool> rename(String name) async {
    final clean = name.trim();
    try {
      final file = await _file();
      if (clean.isEmpty) {
        if (await file.exists()) await file.delete();
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsString(
          clean.length > maxLength ? clean.substring(0, maxLength) : clean,
        );
      }
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'App name: save failed');
      return false;
    }
    await apply();
    return true;
  }

  /// Puts the name in use on the window and the tray. Failing to is a
  /// cosmetic loss, never an error.
  Future<void> apply() async {
    if (!supported) return;
    final String? name;
    try {
      name = await current();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'App name: read failed');
      return;
    }
    // Each place on its own: one that refuses the name must not stop the rest.
    await _tryApply(
      'window title',
      () => windowManager.setTitle(name ?? AppConfig.appName),
    );
    await _tryApply('tray tooltip', () async => _setTrayToolTip?.call(name));
  }

  static Future<void> _tryApply(
    String place,
    Future<void> Function() apply,
  ) async {
    try {
      await apply();
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'App name: $place failed');
    }
  }
}
