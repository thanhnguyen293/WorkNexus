import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/config/app_config.dart';
import 'package:work_nexus/core/platform/desktop_notifier.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockCache extends Mock implements BaseCacheManager {}

void main() {
  late _MockPlugin plugin;
  late List<List<String>> runs;
  late DesktopNotifier notifier;
  late Directory dir;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    dir = Directory.systemTemp.createTempSync('notifier_icon_');
    plugin = _MockPlugin();
    runs = [];
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    notifier = DesktopNotifier(
      plugin: plugin,
      imageCache: _MockCache(),
      isWindows: true,
      runProcess: (exe, args) async {
        runs.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    dir.deleteSync(recursive: true);
  });

  WindowsInitializationSettings registered() =>
      (verify(
                () => plugin.initialize(
                  settings: captureAny(named: 'settings'),
                  onDidReceiveNotificationResponse: any(
                    named: 'onDidReceiveNotificationResponse',
                  ),
                ),
              ).captured.single
              as InitializationSettings)
          .windows!;

  test('registers the name and icon the user gave before starting', () async {
    final icon = File('${dir.path}/custom-1.png')..writeAsBytesSync([1]);
    await notifier.useAppName('Acme Board');
    await notifier.useAppIcon(icon.path);
    await notifier.initialize();

    final windows = registered();
    expect(windows.appName, 'Acme Board');
    expect(windows.iconPath, icon.absolute.path.replaceAll('/', r'\'));
    // Nothing to rewrite: the plugin registered both itself.
    expect(runs, isEmpty);
  });

  test('a rename after starting rewrites the registered name', () async {
    await notifier.initialize();
    await notifier.useAppName('Acme Board');

    final displayName = runs.singleWhere((r) => r.contains('DisplayName'));
    expect(displayName.first, 'reg');
    expect(
      displayName,
      containsAllInOrder([
        'add',
        'HKCU\\Software\\Classes\\AppUserModelId\\${AppConfig.windowsAppId}',
        '/v',
        'DisplayName',
        '/t',
        'REG_SZ',
        '/d',
        'Acme Board',
        '/f',
      ]),
    );
  });

  test('a blank name gives the build its own back', () async {
    await notifier.initialize();
    await notifier.useAppName('Acme Board');
    await notifier.useAppName(null);

    final last = runs.lastWhere((r) => r.contains('DisplayName'));
    expect(last, contains(AppConfig.appName));
  });

  test('a new icon after starting rewrites the registered icon', () async {
    final icon = File('${dir.path}/custom-2.png')..writeAsBytesSync([1]);
    await notifier.initialize();
    await notifier.useAppIcon(icon.path);

    final iconRun = runs.lastWhere((r) => r.contains('IconUri'));
    expect(iconRun, contains(icon.absolute.path.replaceAll('/', r'\')));
  });

  test('does nothing off Windows', () async {
    final mac = DesktopNotifier(
      plugin: plugin,
      imageCache: _MockCache(),
      isWindows: false,
      runProcess: (exe, args) async {
        runs.add([exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
    await mac.initialize();
    await mac.useAppName('Acme Board');
    expect(runs, isEmpty);
  });
}
