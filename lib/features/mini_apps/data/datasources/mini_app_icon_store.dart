import 'dart:typed_data';

/// Where the icon image files of the mini apps are kept, one per app.
abstract interface class MiniAppIconStore {
  /// Keeps [bytes] as app [id]'s icon, replacing any earlier one; resolves to
  /// the file's path.
  Future<String> save(String id, Uint8List bytes, String extension);

  /// Copies the image at [sourcePath] in as app [id]'s icon.
  Future<String> import(String id, String sourcePath);

  /// Removes every icon file kept for app [id].
  Future<void> delete(String id);
}
