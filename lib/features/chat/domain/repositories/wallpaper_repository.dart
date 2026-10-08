import 'dart:typed_data';

import '../../../../core/error/result.dart';

/// Images the user added as chat wallpapers, kept by the app.
abstract class WallpaperRepository {
  /// File paths of the user's wallpapers, newest first.
  Future<Result<List<String>>> wallpapers();

  /// Keeps [bytes] as a wallpaper; returns its file path.
  Future<Result<String>> add(Uint8List bytes, {required String name});

  /// Removes the wallpaper at [path].
  Future<Result<void>> remove(String path);
}
