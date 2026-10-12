import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/platform/linux_desktop_entry.dart';

void main() {
  late Directory apps;

  setUp(() => apps = Directory.systemTemp.createTempSync('apps'));
  tearDown(() => apps.deleteSync(recursive: true));

  File entry() => File('${apps.path}/com.worknexus.workNexus.desktop');

  test('writes an entry that runs the app and matches its window', () async {
    await LinuxDesktopEntry(
      executable: '/opt/Work Nexus/WorkNexus',
      applicationsDir: apps.path,
    ).ensureInstalled();

    final lines = entry().readAsLinesSync();
    expect(lines, contains('Exec="/opt/Work Nexus/WorkNexus"'));
    expect(lines, contains('Icon=/opt/Work Nexus/data/app_icon.png'));
    expect(lines, contains('StartupWMClass=com.worknexus.workNexus'));
  });

  test('escapes what the Exec quoting rules reserve', () async {
    await LinuxDesktopEntry(
      executable: r'/opt/a"b$c%d/WorkNexus',
      applicationsDir: apps.path,
    ).ensureInstalled();

    expect(
      entry().readAsLinesSync(),
      contains(r'Exec="/opt/a\\"b\\$c%%d/WorkNexus"'),
    );
  });

  test('rewrites the entry once the app has moved', () async {
    await LinuxDesktopEntry(
      executable: '/old/WorkNexus',
      applicationsDir: apps.path,
    ).ensureInstalled();
    await LinuxDesktopEntry(
      executable: '/new/WorkNexus',
      applicationsDir: apps.path,
    ).ensureInstalled();

    expect(entry().readAsStringSync(), contains('Exec="/new/WorkNexus"'));
  });
}
