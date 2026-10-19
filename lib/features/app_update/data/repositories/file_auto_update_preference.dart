import 'dart:io';

import '../../domain/repositories/auto_update_preference.dart';

/// The choice kept as a marker file: there is none while automatic updates are
/// on (the default), so a build that never saved it behaves as before.
class FileAutoUpdatePreference implements AutoUpdatePreference {
  FileAutoUpdatePreference({required this._file});

  final Future<File> Function() _file;

  @override
  Future<bool> isEnabled() async => !await (await _file()).exists();

  @override
  Future<void> setEnabled(bool enabled) async {
    final file = await _file();
    if (enabled) {
      if (await file.exists()) await file.delete();
    } else {
      await file.parent.create(recursive: true);
      await file.writeAsString('off');
    }
  }
}
