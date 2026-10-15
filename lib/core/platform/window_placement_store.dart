import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../debug/app_talker.dart';

/// Remembers whether the app window was maximized when last used, in a small
/// JSON file in the app-support directory. It is read before the window is
/// shown — before the database and the rest of the app are set up — so it
/// does not live in drift.
class WindowPlacementStore {
  const WindowPlacementStore();

  static const _fileName = 'window_placement.json';

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');

  /// Whether the window was maximized last time; defaults to true (full screen)
  /// on the first run or when the file cannot be read.
  Future<bool> readMaximized() async {
    try {
      final file = await _file();
      if (!await file.exists()) return true;
      return switch (jsonDecode(await file.readAsString())) {
        {'maximized': false} => false,
        _ => true,
      };
    } on Object catch (e, st) {
      appTalker.handle(e, st, 'Window placement: read failed');
      return true;
    }
  }

  Future<void> writeMaximized(bool maximized) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'maximized': maximized}));
    } on Object catch (e, st) {
      // Only the next launch opening maximized is lost.
      appTalker.handle(e, st, 'Window placement: write failed');
    }
  }
}
