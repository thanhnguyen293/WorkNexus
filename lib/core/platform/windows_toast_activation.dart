import 'dart:io';

import '../debug/app_talker.dart';

/// Runs a command, as [Process.run] does.
typedef CommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Lets a toast click reach the app on Windows.
///
/// Windows hands the click to the toast's activator, a COM class, found
/// through its `LocalServer32` key. The notifications plugin records the
/// activator but not that key, so clicks went nowhere — even with the app
/// open. This names [exePath] as the server, per user (no admin), as
/// Microsoft documents for unpackaged apps. It is read first and written only
/// when it names another exe (a moved or second copy of the app).
class WindowsToastActivation {
  const WindowsToastActivation({
    required this.guid,
    required this.exePath,
    this.run = Process.run,
  });

  /// The activator's class id, as given to the plugin (no braces).
  final String guid;
  final String exePath;
  final CommandRunner run;

  String get key => 'HKCU\\Software\\Classes\\CLSID\\{$guid}\\LocalServer32';

  /// Whether the key now names [exePath].
  Future<bool> ensureRegistered() async {
    final exe = '"$exePath"';
    try {
      final current = await run('reg', ['query', key, '/ve']);
      if (current.exitCode == 0 &&
          '${current.stdout}'.toLowerCase().contains(exe.toLowerCase())) {
        return true;
      }
      final res = await run('reg', ['add', key, '/ve', '/d', exe, '/f']);
      if (res.exitCode == 0) {
        appTalker.info('Notifications: toast activation registered');
        return true;
      }
      appTalker.warning(
        'Notifications: could not register toast activation: ${res.stderr}',
      );
      return false;
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Notifications: registering toast activation');
      return false;
    }
  }
}
