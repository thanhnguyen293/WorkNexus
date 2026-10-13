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

  test('from an AppImage, runs the image and copies its icon out', () async {
    final mount = '${apps.path}/mount';
    await File('$mount/data/app_icon.png').create(recursive: true);
    await File('$mount/data/app_icon.png').writeAsString('png');
    final share = '${apps.path}/share';

    await LinuxDesktopEntry(
      executable: '$mount/WorkNexus',
      applicationsDir: '$share/applications',
      appImage: '/home/me/Apps/WorkNexus.AppImage',
    ).ensureInstalled();

    final icon =
        '$share/icons/hicolor/256x256/apps/com.worknexus.workNexus.png';
    final lines = File(
      '$share/applications/com.worknexus.workNexus.desktop',
    ).readAsLinesSync();
    expect(lines, contains('Exec="/home/me/Apps/WorkNexus.AppImage"'));
    expect(lines, contains('Icon=${icon.replaceAll(r'\', r'\\')}'));
    expect(File(icon).readAsStringSync(), 'png');
  });
}
