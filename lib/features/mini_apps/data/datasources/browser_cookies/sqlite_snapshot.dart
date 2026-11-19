import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Runs [read] over a copy of the SQLite file at [path]. The browser may be
/// running and holding its file locked, and a copy also keeps us from ever
/// touching the original. The write-ahead log goes along, so what the browser
/// wrote last is there too.
Future<T> readSqliteSnapshot<T>(
  String path,
  T Function(Database db) read,
) async {
  final dir = await Directory.systemTemp.createTemp('worknexus_cookies');
  try {
    final copy = '${dir.path}/db.sqlite';
    try {
      await File(path).copy(copy);
    } on FileSystemException catch (e) {
      // Chromium on Windows opens its cookie file for itself alone while it
      // runs: no other process can copy it until the browser is closed.
      if (Platform.isWindows &&
          _sharingViolations.contains(e.osError?.errorCode)) {
        throw CookieStoreInUseException(path);
      }
      rethrow;
    }
    for (final suffix in const ['-wal', '-journal']) {
      final side = File('$path$suffix');
      if (await side.exists()) await side.copy('$copy$suffix');
    }
    final db = sqlite3.open(copy);
    try {
      return read(db);
    } finally {
      db.close();
    }
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Windows' ERROR_SHARING_VIOLATION and ERROR_LOCK_VIOLATION.
const _sharingViolations = {32, 33};

/// The browser is running and holds its cookie file for itself.
class CookieStoreInUseException implements Exception {
  const CookieStoreInUseException(this.path);

  final String path;

  @override
  String toString() => 'CookieStoreInUseException($path)';
}
