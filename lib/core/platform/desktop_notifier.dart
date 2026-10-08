import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../debug/app_talker.dart';

/// OS notifications (Notification Center, Windows toasts, freedesktop) so
/// the rest of the app never imports the plugin. [taps] emits the payload of
/// a notification the user clicked.
class DesktopNotifier {
  DesktopNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _appName = 'WorkNexus';

  // Windows ties toasts to an AppUserModelID + COM activator GUID; both must
  // stay stable across releases or Windows treats it as a different app.
  static const _windowsAppId = 'WorkNexus.WorkNexus.Desktop';
  static const _windowsGuid = 'c14901d9-c46d-4d26-9596-9c14e5a0e0b7';

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
        !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return false;
    }
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(requestBadgePermission: false),
          windows: WindowsInitializationSettings(
            appName: _appName,
            appUserModelId: _windowsAppId,
            guid: _windowsGuid,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _taps.add(payload);
        },
      );
      appTalker.info('Notifications: initialize -> $ok');
      return ok ?? false;
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Notifications: initialize failed');
      return false;
    }
  }

  /// Shows a notification; one with the same [id] replaces the previous
  /// one (e.g. one per conversation).
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await initialize()) {
      appTalker.warning('Notifications: not allowed, "$title" not shown');
      return;
    }
    try {
      await _plugin.show(id: id, title: title, body: body, payload: payload);
      appTalker.info('Notifications: shown "$title"');
    } on Exception catch (e, st) {
      // Not worth interrupting the user over; the unread badge still shows.
      appTalker.handle(e, st, 'Notifications: show failed');
    }
  }
}
