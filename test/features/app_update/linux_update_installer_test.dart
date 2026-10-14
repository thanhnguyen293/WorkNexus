import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/app_update/data/datasources/linux_update_installer.dart';

/// The swap script and its fixtures run under `/bin/sh`, `chmod` and `true`.
final _noShell = Platform.isWindows ? 'needs a POSIX shell' : null;

void main() {
  late Directory root;
  late String install;
  late String staged;
  late String marker;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('linux_update_test');
    install = '${root.path}/bundle';
    staged = '${root.path}/staged';
    marker = '${root.path}/started';
    await File('$install/old.txt').create(recursive: true);
    await File('$staged/new.txt').create(recursive: true);
    final exe = File('$staged/run.sh');
    await exe.writeAsString('#!/bin/sh\ntouch "$marker"\n');
    await Process.run('chmod', ['+x', exe.path]);
  });

  tearDown(() => root.delete(recursive: true));

  /// Runs the swap script as the app's detached helper would, against a pid
  /// that has already exited.
  Future<void> swap(String source) async {
    final exited = await Process.start('true', []);
    await exited.exitCode;
    final script = File('${root.path}/install_update.sh');
    await script.writeAsString(LinuxUpdateInstaller.script);
    final result = await Process.run('/bin/sh', [
      script.path,
      '${exited.pid}',
      install,
      source,
      '$install/run.sh',
      '${root.path}/update.log',
    ]);
    expect(result.exitCode, 0);
  }

  test(
    'replaces the bundle and starts the new build',
    skip: _noShell,
    () async {
      await swap(staged);

      expect(File('$install/new.txt').existsSync(), isTrue);
      expect(File('$install/old.txt').existsSync(), isFalse);
      expect(Directory('$install.previous').existsSync(), isFalse);
      expect(Directory('$install.new').existsSync(), isFalse);
      // The app is started in the background; give it a moment.
      for (var i = 0; i < 50 && !File(marker).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(File(marker).existsSync(), isTrue);
    },
  );

  test(
    'keeps the old bundle when the new one cannot be copied',
    skip: _noShell,
    () async {
      await swap('${root.path}/missing');

      expect(File('$install/old.txt').existsSync(), isTrue);
      expect(Directory('$install.previous').existsSync(), isFalse);
      expect(Directory('$install.new').existsSync(), isFalse);
    },
  );
}
