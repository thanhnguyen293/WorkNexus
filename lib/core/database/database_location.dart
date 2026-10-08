import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// On-disk database name — the file is `<kDatabaseName>.sqlite`.
const kDatabaseName = 'worknexus';

/// Where the drift file lives: the application-support directory, a private
/// per-app location the user never reorganises.
///
/// drift's own default is the *documents* directory, which on an unsandboxed
/// macOS build is `~/Documents`. Tidying that folder moved the database away
/// and the app silently opened a brand-new, empty one — so a database left
/// there is moved here once, on the first run after this change.
Future<Directory> resolveDatabaseDirectory() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  await migrateLegacyDatabase(
    from: await getApplicationDocumentsDirectory(),
    to: dir,
  );
  return dir;
}

/// Moves the database (with its `-wal`/`-shm` siblings) from [from] to [to].
///
/// A no-op once [to] holds a database, so it never overwrites the live file,
/// and best-effort: a move we cannot complete (permissions, a separate volume)
/// must not block startup — the old file then stays where it is and can be
/// moved by hand, while the app opens an empty database in the new location.
Future<void> migrateLegacyDatabase({
  required Directory from,
  required Directory to,
}) async {
  final target = '${to.path}/$kDatabaseName.sqlite';
  try {
    if (await File(target).exists()) return;
    final legacy = '${from.path}/$kDatabaseName.sqlite';
    if (!await File(legacy).exists()) return;
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$legacy$suffix');
      if (await file.exists()) await file.rename('$target$suffix');
    }
  } on FileSystemException catch (_) {
    // Best-effort — see the doc comment above.
  }
}
