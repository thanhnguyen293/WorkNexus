import 'dart:io';

/// Bytes the files under [dir] take, recursively; 0 when it doesn't exist.
Future<int> directoryBytes(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) total += await entity.length();
  }
  return total;
}
