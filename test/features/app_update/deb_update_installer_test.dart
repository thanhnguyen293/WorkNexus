import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/app_update/data/datasources/deb_update_installer.dart';

/// The restart script and its fixtures run under `/bin/sh`, `chmod` and `true`.
final _noShell = Platform.isWindows ? 'needs a POSIX shell' : null;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('deb_update_test');
  });

  tearDown(() => root.delete(recursive: true));

  group('installedFromDeb', () {
    Future<void> writeList(List<String> paths) => File(
      '${root.path}/${DebUpdateInstaller.packageName}.list',
    ).writeAsString('${paths.join('\n')}\n');

    test('is true when the package lists the running binary', () async {
      await writeList(['/opt/worknexus', '/opt/worknexus/WorkNexus']);

      expect(
        DebUpdateInstaller.installedFromDeb(
          dpkgInfo: root.path,
          executable: '/opt/worknexus/WorkNexus',
        ),
        isTrue,
      );
    });

    test('is false for a binary the package does not hold', () async {
      await writeList(['/opt/worknexus/WorkNexus']);

      expect(
        DebUpdateInstaller.installedFromDeb(
          dpkgInfo: root.path,
          executable: '/home/me/worknexus/WorkNexus',
        ),
        isFalse,
      );
    });

    test('is false when the package is not installed', () {
      expect(
        DebUpdateInstaller.installedFromDeb(
          dpkgInfo: root.path,
          executable: '/opt/worknexus/WorkNexus',
        ),
        isFalse,
      );
    });
  });

  test(
    'restarts the app once the old process has exited',
    skip: _noShell,
    () async {
      final marker = '${root.path}/started';
      final exe = File('${root.path}/run.sh');
      await exe.writeAsString('#!/bin/sh\ntouch "$marker"\n');
      await Process.run('chmod', ['+x', exe.path]);
      final exited = await Process.start('true', []);
      await exited.exitCode;
      final script = File('${root.path}/restart.sh');
      await script.writeAsString(DebUpdateInstaller.restartScript);

      final result = await Process.run('/bin/sh', [
        script.path,
        '${exited.pid}',
        exe.path,
        '${root.path}/update.log',
      ]);

      expect(result.exitCode, 0);
      // The app is started in the background; give it a moment.
      for (var i = 0; i < 50 && !File(marker).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(File(marker).existsSync(), isTrue);
    },
  );
}
