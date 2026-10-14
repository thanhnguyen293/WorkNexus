import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/app_update/data/datasources/appimage_update_installer.dart';

/// The swap script and its fixtures run under `/bin/sh`, `chmod` and `true`.
final _noShell = Platform.isWindows ? 'needs a POSIX shell' : null;

void main() {
  late Directory root;
  late String installed;
  late String staged;
  late String marker;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('appimage_update_test');
    installed = '${root.path}/WorkNexus.AppImage';
    staged = '${root.path}/staged.AppImage';
    marker = '${root.path}/started';
    await File(installed).writeAsString('#!/bin/sh\n# old\n');
    // Downloads arrive without the executable bit; the swap sets it.
    await File(staged).writeAsString('#!/bin/sh\ntouch "$marker"\n');
  });

  tearDown(() => root.delete(recursive: true));

  /// Runs the swap script as the app's detached helper would, against a pid
  /// that has already exited.
  Future<void> swap(String source) async {
    final exited = await Process.start('true', []);
    await exited.exitCode;
    final script = File('${root.path}/install_update.sh');
    await script.writeAsString(AppImageUpdateInstaller.script);
    final result = await Process.run('/bin/sh', [
      script.path,
      '${exited.pid}',
      installed,
      source,
      '${root.path}/update.log',
    ]);
    expect(result.exitCode, 0);
  }

  test('the download is the build: nothing is unpacked', () async {
    const installer = AppImageUpdateInstaller('/apps/WorkNexus.AppImage');

    expect(await installer.unpack(staged, root.path), staged);
    expect(installer.installPath, '/apps/WorkNexus.AppImage');
  });

  test('replaces the image and starts the new one', skip: _noShell, () async {
    await swap(staged);

    expect(File(installed).readAsStringSync(), contains('touch'));
    expect(File('$installed.new').existsSync(), isFalse);
    // The app is started in the background; give it a moment.
    for (var i = 0; i < 50 && !File(marker).existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(File(marker).existsSync(), isTrue);
  });

  test(
    'keeps the old image when the new one cannot be copied',
    skip: _noShell,
    () async {
      await swap('${root.path}/missing');

      expect(File(installed).readAsStringSync(), contains('# old'));
      expect(File('$installed.new').existsSync(), isFalse);
    },
  );
}
