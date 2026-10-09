import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import '../debug/app_talker.dart';

/// OS notifications (Notification Center, Windows toasts, freedesktop) so
/// the rest of the app never imports the plugin. [taps] emits the payload of
/// a notification the user clicked.
class DesktopNotifier {
  DesktopNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
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
          macOS: const DarwinInitializationSettings(
            requestBadgePermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: AppConfig.appName,
            appUserModelId: AppConfig.windowsAppId,
            guid: AppConfig.windowsGuid,
            iconPath: _windowsIconPath(),
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
      return await mac.requestPermissions(alert: true, sound: true) ?? false;
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
        notificationDetails: _details(imageUrl),
      );
      appTalker.info('Notifications: shown "$title"');
    } on Exception catch (e, st) {
      // Not worth interrupting the user over; the unread badge still shows.
      appTalker.handle(e, st, 'Notifications: show failed');
    }
  }

  /// The sender's picture in place of the app logo on a Windows toast. The
  /// toast fetches the https URL itself; other platforms have no equivalent.
  NotificationDetails? _details(String? imageUrl) {
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    if (uri == null ||
        !uri.hasScheme ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return null;
    }
    return NotificationDetails(
      windows: WindowsNotificationDetails(
        images: [
          WindowsImage(
            uri,
            altText: '',
            placement: WindowsImagePlacement.appLogoOverride,
            crop: WindowsImageCrop.circle,
          ),
        ],
      ),
    );
  }

  /// The bundled app icon, shown beside the app name on a Windows toast; null
  /// when the build has no such file (the toast then shows no icon).
  static String? _windowsIconPath() {
    if (kIsWeb || !Platform.isWindows) return null;
    final dir = File(Platform.resolvedExecutable).parent.path;
    final icon = File('$dir/data/flutter_assets/assets/tray/app_icon.png');
    return icon.existsSync() ? icon.path : null;
  }
}
