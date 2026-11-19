import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../domain/entities/app_ref.dart';
import '../../domain/repositories/app_switcher.dart';
import '../datasources/linux_desktop_apps.dart';

/// [AppSwitcher] on Linux, best effort. On X11 `wmctrl` raises a running app
/// and lists the windows, and `xdotool` minimises them. Wayland lets no app raise or hide another's
/// windows, so there the app is only (re)launched with `gtk-launch` — a
/// single-instance app usually comes forward — and hiding does nothing.
class LinuxAppSwitcher implements AppSwitcher {
  const LinuxAppSwitcher([
    this._apps = const LinuxDesktopApps(),
    this._window = const DesktopWindowService(),
  ]);

  final LinuxDesktopApps _apps;
  final DesktopWindowService _window;

  @override
  bool get canRaiseApps => isX11;

  static bool get isX11 =>
      Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() == 'x11';

  @override
  Future<Result<List<AppRef>>> listApps() async {
    try {
      return Ok([
        for (final app in await _apps.list())
          AppRef(id: app.id, name: app.name),
      ]);
    } on Object catch (e) {
      return Err(UnexpectedFailure('Could not list the apps', cause: e));
    }
  }

  @override
  Future<Result<void>> activate(AppRef app) async {
    try {
      if (isX11) {
        final wmClass = (await _apps.find(app.id))?.wmClass ?? app.id;
        if (await _run('wmctrl', ['-x', '-a', wmClass])) return const Ok(null);
      }
      if (await _run('gtk-launch', [app.id])) return const Ok(null);
      return Err(UnexpectedFailure('Could not open ${app.name}'));
    } on Object catch (e) {
      return Err(UnexpectedFailure('Could not open ${app.name}', cause: e));
    }
  }

  @override
  Future<Result<void>> hideOthers(List<AppRef> keep) async {
    if (!isX11) return const Ok(null);
    try {
      final kept = <String>{
        for (final app in keep)
          ((await _apps.find(app.id))?.wmClass ?? app.id).toLowerCase(),
      };
      // `wmctrl -l -x -p`: id, desktop, pid, WM_CLASS ("instance.Class"),
      // host, title. Desktop -1 is sticky (panels, the floating button).
      final listed = await Process.run('wmctrl', ['-l', '-x', '-p']);
      if (listed.exitCode != 0) {
        return const Err(UnexpectedFailure('Could not list the windows'));
      }
      for (final line in (listed.stdout as String).split('\n')) {
        final cols = line.split(RegExp(r'\s+'));
        if (cols.length < 4 || cols[1] == '-1') continue;
        if (int.tryParse(cols[2]) == pid) continue;
        final wmClass = cols[3].toLowerCase();
        if (kept.any((k) => wmClass.split('.').contains(k))) continue;
        await _run('xdotool', ['windowminimize', cols[0]]);
      }
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure('Could not hide the other apps', cause: e));
    }
  }

  @override
  Future<Result<void>> hideSelf() async {
    try {
      await _window.minimize();
      return const Ok(null);
    } on Object catch (e) {
      return Err(UnexpectedFailure('Could not hide WorkNexus', cause: e));
    }
  }

  // A missing tool (ProcessException) counts as "did not work".
  static Future<bool> _run(String tool, List<String> args) async {
    try {
      return (await Process.run(tool, args)).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
