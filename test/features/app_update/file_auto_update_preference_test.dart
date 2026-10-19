import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/app_update/data/repositories/file_auto_update_preference.dart';

void main() {
  late Directory dir;
  late FileAutoUpdatePreference preference;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('auto_update_');
    preference = FileAutoUpdatePreference(
      file: () async => File('${dir.path}/sub/auto_update.txt'),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('is on until it is turned off', () async {
    expect(await preference.isEnabled(), isTrue);
  });

  test('stays off once turned off, and on again when turned on', () async {
    await preference.setEnabled(false);
    expect(await preference.isEnabled(), isFalse);

    await preference.setEnabled(true);
    expect(await preference.isEnabled(), isTrue);
  });

  test('turning it on when it was never off changes nothing', () async {
    await preference.setEnabled(true);
    expect(await preference.isEnabled(), isTrue);
  });
}
