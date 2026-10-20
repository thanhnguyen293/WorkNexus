import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/app_update/data/datasources/auto_update_marker_file.dart';
import 'package:work_nexus/features/app_update/data/repositories/local_auto_update_preference.dart';

void main() {
  late Directory dir;
  late LocalAutoUpdatePreference preference;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('auto_update_');
    preference = LocalAutoUpdatePreference(
      AutoUpdateMarkerFile(
        file: () async => File('${dir.path}/sub/auto_update.txt'),
      ),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<bool?> enabled() async => (await preference.isEnabled()).valueOrNull;

  test('is on until it is turned off', () async {
    expect(await enabled(), isTrue);
  });

  test('stays off once turned off, and on again when turned on', () async {
    await preference.setEnabled(false);
    expect(await enabled(), isFalse);

    await preference.setEnabled(true);
    expect(await enabled(), isTrue);
  });

  test('turning it on when it was never off changes nothing', () async {
    expect((await preference.setEnabled(true)).isOk, isTrue);
    expect(await enabled(), isTrue);
  });

  test('a choice it cannot save is a StorageFailure, not a throw', () async {
    // A file where the folder should be: the marker cannot be written.
    File('${dir.path}/sub').createSync();
    final result = await preference.setEnabled(false);
    expect(result.failureOrNull, isA<StorageFailure>());
  });
}
