import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database_location.dart';

/// The one-time move of a `~/Documents`-era database into the app-support
/// directory. A documents folder the user reorganises silently detached the
/// database and the app opened an empty one — these pin the move's guarantees.
void main() {
  late Directory legacy;
  late Directory target;

  File dbIn(Directory dir, [String suffix = '']) =>
      File('${dir.path}/$kDatabaseName.sqlite$suffix');

  setUp(() async {
    legacy = await Directory.systemTemp.createTemp('wn_legacy');
    target = await Directory.systemTemp.createTemp('wn_target');
  });

  tearDown(() async {
    for (final dir in [legacy, target]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('moves the database and its -wal/-shm siblings', () async {
    await dbIn(legacy).writeAsString('main');
    await dbIn(legacy, '-wal').writeAsString('wal');
    await dbIn(legacy, '-shm').writeAsString('shm');

    await migrateLegacyDatabase(from: legacy, to: target);

    expect(await dbIn(target).readAsString(), 'main');
    expect(await dbIn(target, '-wal').readAsString(), 'wal');
    expect(await dbIn(target, '-shm').readAsString(), 'shm');
    expect(await dbIn(legacy).exists(), isFalse);
  });

  test('moves the database when no -wal/-shm sidecar exists', () async {
    await dbIn(legacy).writeAsString('main');

    await migrateLegacyDatabase(from: legacy, to: target);

    expect(await dbIn(target).readAsString(), 'main');
    expect(await dbIn(target, '-wal').exists(), isFalse);
  });

  test('never overwrites a database already in the target', () async {
    await dbIn(legacy).writeAsString('old');
    await dbIn(target).writeAsString('live');

    await migrateLegacyDatabase(from: legacy, to: target);

    expect(await dbIn(target).readAsString(), 'live');
    expect(await dbIn(legacy).readAsString(), 'old');
  });

  test('is a no-op when there is nothing to move', () async {
    await migrateLegacyDatabase(from: legacy, to: target);

    expect(await dbIn(target).exists(), isFalse);
  });

  test('a missing legacy directory does not throw', () async {
    await legacy.delete(recursive: true);

    await expectLater(
      migrateLegacyDatabase(from: legacy, to: target),
      completes,
    );
  });
}
