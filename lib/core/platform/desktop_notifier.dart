import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import '../debug/app_talker.dart';

/// Runs a command to completion; [Process.run] outside tests.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// OS notifications (Notification Center, Windows toasts, freedesktop) so
/// the rest of the app never imports the plugin. [taps] emits the payload of
/// a notification the user clicked.
class DesktopNotifier {
  DesktopNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    BaseCacheManager? imageCache,
    @visibleForTesting bool? isWindows,
    @visibleForTesting ProcessRunner? runProcess,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _cache = imageCache ?? DefaultCacheManager(),
       _isWindows = isWindows ?? (!kIsWeb && Platform.isWindows),
       _runProcess = runProcess ?? Process.run;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _isWindows;
  final ProcessRunner _runProcess;

  /// The name and icon a Windows toast shows beside its text: the ones the
  /// user gave the app ([useAppName], [useAppIcon]), the build's own otherwise.
  String _appName = AppConfig.appName;
  String? _customIconPath;

  /// cached_network_image's default cache, so a picture the chat already
  /// showed is not downloaded again.
  final BaseCacheManager _cache;
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _ready;

  Stream<String> get taps => _taps.stream;

  /// Sets the plugin up (asking macOS for permission the first time).
  /// Returns false where notifications are unavailable; [show] then no-ops.
  Future<bool> initialize() async {
    final ok = await (_ready ??= _initialize());
    // Not cached when it failed: permission may be granted in System
    // Settings later, and the next message should try again.
    if (!ok) _ready = null;
    return ok;
  }

  Future<bool> _initialize() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return false;
    }
    try {
      final ok = await _plugin.initialize(
        settings: InitializationSettings(
          // Badge permission is asked too (the default): macOS hides the
          // Dock badge of unread chats (AppIconBadge) when it is not given.
          macOS: const DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: _appName,
            appUserModelId: AppConfig.windowsAppId,
            guid: AppConfig.windowsGuid,
            iconPath: _iconPath(),
          ),
          linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _taps.add(payload);
        },
      );
      appTalker.info('Notifications: initialize -> $ok');
      return ok ?? false;
    } catch (e, st) {
      appTalker.handle(e, st, 'Notifications: initialize failed');
      return false;
    }
  }

  /// Shows [name] on Windows toasts in place of the build's own (null gives
  /// that back). The plugin registers the app's name and icon once, when it
  /// starts; a change after that is written to the same registry entry, which
  /// Windows reads for each toast. macOS and Linux take the name and icon
  /// from the installed app itself.
  Future<void> useAppName(String? name) async {
    if (!_isWindows) return;
    _appName = name ?? AppConfig.appName;
    await _refreshRegistration();
  }

  /// Shows the picture at [iconPath] on Windows toasts in place of the
  /// bundled icon (null gives that back); see [useAppName].
  Future<void> useAppIcon(String? iconPath) async {
    if (!_isWindows) return;
    _customIconPath = iconPath;
    await _refreshRegistration();
  }

  Future<void> _refreshRegistration() async {
    final ready = _ready;
    // Not started yet: initializing registers what was just set.
    if (ready == null || !await ready) return;
    await _writeRegistration();
  }

  /// `HKCU\Software\Classes\AppUserModelId\<id>`, the entry the plugin
  /// fills with the toast's name and icon.
  Future<void> _writeRegistration() async {
    const entry =
        'HKCU\\Software\\Classes\\AppUserModelId\\${AppConfig.windowsAppId}';
    final icon = _iconPath();
    final values = {'DisplayName': _appName, 'IconUri': ?icon};
    for (final MapEntry(key: name, :value) in values.entries) {
      try {
        final run = await _runProcess('reg', [
          'add',
          entry,
          '/v',
          name,
          '/t',
          'REG_SZ',
          '/d',
          value,
          '/f',
        ]);
        if (run.exitCode != 0) {
          appTalker.warning(
            'Notifications: writing $name failed: ${run.stderr}',
          );
        }
      } on Object catch (e, st) {
        appTalker.handle(e, st, 'Notifications: writing $name failed');
      }
    }
  }

  /// Whether the OS lets the app show alerts: false when notifications or
  /// their banners/alerts are turned off for it (macOS), null where that
  /// cannot be known (other platforms, plugin failure).
  Future<bool?> permissionGranted() async {
    final mac = await _macOS();
    if (mac == null) return null;
    try {
      final options = await mac.checkPermissions();
      if (options == null) return null;
      return options.isEnabled && options.isAlertEnabled;
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Notifications: checkPermissions failed');
      return null;
    }
  }

  /// Asks for permission. macOS only shows its prompt once; after the user
  /// declined, it can only be changed in System Settings
  /// ([openSystemSettings]).
  Future<bool> requestPermission() async {
    final mac = await _macOS();
    if (mac == null) return false;
    try {
      // The badge too: macOS hides the Dock's unread count without it.
      return await mac.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Notifications: requestPermissions failed');
      return false;
    }
  }

  /// Opens the OS notification settings for this app.
  Future<void> openSystemSettings() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.Notifications-Settings.extension'
            '?id=${AppConfig.macBundleId}',
      ]);
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Notifications: opening settings failed');
    }
  }

  Future<MacOSFlutterLocalNotificationsPlugin?> _macOS() async {
    if (kIsWeb || !Platform.isMacOS) return null;
    await initialize();
    return _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
  }

  /// Shows a notification; one with the same [id] replaces the previous
  /// one (e.g. one per conversation).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    if (!await initialize()) {
      appTalker.warning('Notifications: not allowed, "$title" not shown');
      return;
    }
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: await _details(imageUrl),
      );
      appTalker.info('Notifications: shown "$title"');
    } on Exception catch (e, st) {
      // Not worth interrupting the user over; the unread badge still shows.
      appTalker.handle(e, st, 'Notifications: show failed');
    }
  }

  /// The sender's picture in place of the app logo on a Windows toast; other
  /// platforms have no equivalent. A toast from an unpackaged (non-MSIX) app
  /// only loads local files, never https, so the picture is read from the
  /// image cache the chat UI fills (downloading it when it is not there yet).
  /// Without it the toast shows the app icon instead.
  Future<NotificationDetails?> _details(String? imageUrl) async {
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    if (uri == null ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return null;
    }
    final File file;
    try {
      file = await _cache
          .getSingleFile(imageUrl!)
          .timeout(const Duration(seconds: 5));
    } on Object catch (e, st) {
      appTalker.handle(e, st, 'Notifications: avatar download failed');
      return null;
    }
    return NotificationDetails(
      windows: WindowsNotificationDetails(
        images: [
          WindowsImage(
            Uri.file(file.absolute.path, windows: true),
            altText: '',
            placement: WindowsImagePlacement.appLogoOverride,
            crop: WindowsImageCrop.circle,
          ),
        ],
      ),
    );
  }

  /// The icon beside the app name on a Windows toast: the user's picture,
  /// the bundled one otherwise. Windows reads it as a plain path, so it is
  /// written with backslashes only.
  String? _iconPath() {
    final custom = _customIconPath;
    if (custom != null && File(custom).existsSync()) {
      return File(custom).absolute.path.replaceAll('/', r'\');
    }
    return _windowsIconPath();
  }

  /// The bundled app icon, shown beside the app name on a Windows toast; null
  /// when the build has no such file (the toast then shows no icon). Windows
  /// reads it from the registry as a plain path, so it is written with
  /// backslashes only — a mixed `\…/…` path is not shown.
  static String? _windowsIconPath() {
    if (kIsWeb || !Platform.isWindows) return null;
    final dir = File(Platform.resolvedExecutable).parent.path;
    final icon = File(
      [
        dir,
        'data',
        'flutter_assets',
        'assets',
        'tray',
        'app_icon_256.png',
      ].join(r'\'),
    );
    return icon.existsSync() ? icon.absolute.path : null;
  }
}
