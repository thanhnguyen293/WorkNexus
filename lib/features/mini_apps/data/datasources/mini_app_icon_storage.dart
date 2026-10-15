import 'dart:io';
import 'dart:typed_data';

import 'mini_app_icon_store.dart';

/// The icon image files of the mini apps, one per app, in a folder of the
/// app's support directory. A file's name carries a timestamp so a replaced
/// icon is a new path (Flutter caches images by path).
class MiniAppIconStorage implements MiniAppIconStore {
  const MiniAppIconStorage(this._folder);

  final Future<Directory> Function() _folder;

  @override
  Future<String> save(String id, Uint8List bytes, String extension) async {
    final dir = await _folder();
    await dir.create(recursive: true);
    await delete(id);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${dir.path}${Platform.pathSeparator}${id}_$stamp.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<String> import(String id, String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot < 0 ? 'png' : sourcePath.substring(dot + 1).toLowerCase();
    return save(id, bytes, ext);
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _folder();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.startsWith('${id}_')) await entity.delete();
    }
  }
}
