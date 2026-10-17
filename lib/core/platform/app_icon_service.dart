import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../debug/app_talker.dart';
import 'app_icon_image.dart';

/// The app's own icon, which the user can replace with a picture of theirs:
/// the window's (title bar, taskbar button, Alt-Tab) and the tray's. The one
/// kept — a square PNG and the `.ico` the tray takes — lives in the app's
/// support folder, so the original can be moved or deleted.
///
/// Windows only: the file's own icon (Explorer, the Start menu, a pinned
/// shortcut) is part of the `.exe` and cannot change while the app runs.
class AppIconService {
  AppIconService({
    Future<Directory> Function()? folder,
    MethodChannel? channel,
    this._setTrayIcon,
  }) : _folder = folder ?? _supportFolder,
       _channel = channel ?? const MethodChannel('worknexus/app_icon');

  static bool get supported => !kIsWeb && Platform.isWindows;

  static const _prefix = 'custom-';
  static const _smallSide = 32;

  final Future<Directory> Function() _folder;
  final MethodChannel _channel;
  final Future<void> Function(String? iconPath)? _setTrayIcon;

  static Future<Directory> _supportFolder() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/app_icon');

  /// The picture in use, or null while the app has its own icon.
  Future<File?> current() async {
    final folder = await _folder();
    if (!await folder.exists()) return null;
    await for (final entry in folder.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && name.startsWith(_prefix) && name.endsWith('.png')) {
        return entry;
      }
    }
    return null;
  }

  /// Makes the image at [sourcePath] the app's icon. False when it is not an
  /// image or cannot be read or kept (nothing changes then, or the app is
  /// left with its own icon).
  Future<bool> choose(String sourcePath) async {
    try {
      final png = await compute(
        squareAppIconPng,
        await File(sourcePath).readAsBytes(),
      );
      if (png == null) return false;
      final folder = await _folder();
      await _clear(folder);
      await folder.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await File('${folder.path}/$_prefix$stamp.png').writeAsBytes(png);
      await File(
        '${folder.path}/$_prefix$stamp.ico',
      ).writeAsBytes(appIconIco(png));
    } on Object catch (error, stackTrace) {
      // A corrupt image makes the decoder throw, not return null.
      appTalker.handle(error, stackTrace, 'App icon: choose failed');
      // What is left (if anything) goes on the window and the tray.
      await apply();
      return false;
    }
    await apply();
    return true;
  }

  /// Gives the app its own icon back.
  Future<void> reset() async {
    try {
      await _clear(await _folder());
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'App icon: reset failed');
    }
    await apply();
  }

  /// Puts the icon in use (the app's own when there is none) on the window
  /// and the tray. Failing to is a cosmetic loss, never an error.
  Future<void> apply() async {
    if (!supported) return;
    try {
      final png = await current();
      final bytes = await png?.readAsBytes();
      Map<String, Object>? icons;
      if (bytes != null) {
        icons = {
          'large': await _rgba(bytes, kAppIconSide),
          'largeSize': kAppIconSide,
          'small': await _rgba(bytes, _smallSide),
          'smallSize': _smallSide,
        };
      }
      await _channel.invokeMethod<void>('set', icons);
      await _setTrayIcon?.call(
        png?.path.replaceFirst(RegExp(r'\.png$'), '.ico'),
      );
    } on Object catch (error, stackTrace) {
      appTalker.handle(error, stackTrace, 'App icon: apply failed');
    }
  }

  Future<void> _clear(Directory folder) async {
    if (!await folder.exists()) return;
    await for (final entry in folder.list()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith(_prefix)) {
        await entry.delete();
      }
    }
  }

  /// [png] drawn [side] pixels wide, as straight RGBA rows.
  static Future<Uint8List> _rgba(Uint8List png, int side) async {
    final codec = await ui.instantiateImageCodec(
      png,
      targetWidth: side,
      targetHeight: side,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) throw StateError('The icon could not be drawn');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
