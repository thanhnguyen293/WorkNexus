import 'dart:io';

/// The marker file that says automatic updates are off: there is none while
/// they are on (the default), so a build that never saved the choice behaves
/// as before. Throws on a file it cannot read or write.
class AutoUpdateMarkerFile {
  AutoUpdateMarkerFile({required this._file});

  final Future<File> Function() _file;

  Future<bool> exists() async => (await _file()).exists();

  Future<void> create() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString('off');
  }

  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
