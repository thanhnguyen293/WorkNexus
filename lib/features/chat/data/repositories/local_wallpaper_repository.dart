import 'dart:io';
import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/wallpaper_repository.dart';

const _imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'};

/// Wallpapers are files in [directory], named `<epoch ms>_<name>` so the
/// newest sort first.
class LocalWallpaperRepository implements WallpaperRepository {
  LocalWallpaperRepository({required Future<Directory> Function() directory})
    : _directory = directory;

  final Future<Directory> Function() _directory;

  @override
  Future<Result<List<String>>> wallpapers() async {
    try {
      final dir = await _directory();
      if (!dir.existsSync()) return const Ok([]);
      final paths = [
        for (final f in dir.listSync().whereType<File>())
          if (_isImage(f.path)) f.path,
      ]..sort((a, b) => b.compareTo(a));
      return Ok(paths);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not list wallpapers', cause: e));
    }
  }

  @override
  Future<Result<String>> add(Uint8List bytes, {required String name}) async {
    if (bytes.isEmpty) {
      return const Err(UnexpectedFailure('Cannot use an empty image'));
    }
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final safe = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_'
        '${_isImage(safe) ? safe : '$safe.png'}',
      );
      await file.writeAsBytes(bytes, flush: true);
      return Ok(file.path);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not keep the wallpaper', cause: e));
    }
  }

  @override
  Future<Result<void>> remove(String path) async {
    try {
      final dir = await _directory();
      final file = File(path);
      // Only files this repository keeps.
      if (file.parent.path != dir.path) {
        return const Err(UnexpectedFailure('Not a saved wallpaper'));
      }
      if (file.existsSync()) await file.delete();
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not remove the wallpaper', cause: e));
    }
  }

  static bool _isImage(String path) =>
      _imageExtensions.contains(path.split('.').last.toLowerCase());
}
