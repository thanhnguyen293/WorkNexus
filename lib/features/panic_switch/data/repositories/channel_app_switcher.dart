import 'dart:io';

import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/repositories/app_switcher.dart';
import '../datasources/panic_switch_channel.dart';

/// [AppSwitcher] on macOS and Windows, done by the runner's native code.
class ChannelAppSwitcher implements AppSwitcher {
  ChannelAppSwitcher(this._channel, {DesktopWindowService? window})
    : _window = window ?? const DesktopWindowService();

  final PanicSwitchChannel _channel;
  final DesktopWindowService _window;

  @override
  bool get canRaiseApps => true;

  @override
  Future<Result<List<AppRef>>> listApps() => _guard(
    'list the apps',
    () async => [
      for (final app in await _channel.listApps())
        AppRef(id: app.id, name: app.name),
    ],
  );

  @override
  Future<Result<Uint8List?>> appIcon(AppRef app) =>
      _guard('read the icon of ${app.name}', () => _channel.appIcon(app.id));

  @override
  Future<Result<void>> activate(AppRef app) =>
      _guard('open ${app.name}', () => _channel.activate(app.id));

  @override
  Future<Result<void>> hideOthers(List<AppRef> keep) => _guard(
    'hide the other apps',
    () => _channel.hideOthers([for (final a in keep) a.id]),
  );

  // macOS hides the whole app (Dock icon stays); Windows minimises, so the
  // window is one taskbar click away rather than tucked into the tray.
  @override
  Future<Result<void>> hideSelf() => _guard(
    'hide WorkNexus',
    () => Platform.isMacOS ? _channel.hideSelf() : _window.minimize(),
  );

  static Future<Result<T>> _guard<T>(
    String what,
    Future<T> Function() run,
  ) async {
    try {
      return Ok(await run());
    } on PlatformException catch (e) {
      return Err(UnexpectedFailure('Could not $what: ${e.message}', cause: e));
    } on MissingPluginException catch (e) {
      return Err(UnexpectedFailure('Could not $what', cause: e));
    }
  }
}
