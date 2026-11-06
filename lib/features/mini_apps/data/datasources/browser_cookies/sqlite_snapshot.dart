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
    await File(path).copy(copy);
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
