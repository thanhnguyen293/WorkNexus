import 'dart:io';

import '../config/app_config.dart';
import '../debug/app_talker.dart';

/// Writes the app's `.desktop` entry into the user's applications folder on
/// launch, as Telegram Desktop does. The Linux release is a bare tarball with
/// no installer, and without an entry a dock shows neither the app's icon nor
/// its unread badge: it ties the window to the entry by
/// [AppConfig.linuxAppId].
class LinuxDesktopEntry {
  LinuxDesktopEntry({String? executable, String? applicationsDir})
    : _executable = executable ?? Platform.resolvedExecutable,
      _applicationsDir = applicationsDir ?? _defaultApplicationsDir();

  final String _executable;
  final String _applicationsDir;

  static String _defaultApplicationsDir() {
    final env = Platform.environment;
    final dataHome = env['XDG_DATA_HOME'];
    final base = dataHome != null && dataHome.isNotEmpty
        ? dataHome
        : '${env['HOME']}/.local/share';
    return '$base/applications';
  }

  /// Writes the entry, or rewrites it when the app has moved since; leaves an
  /// up-to-date one untouched.
  Future<void> ensureInstalled() async {
    try {
      final file = File('$_applicationsDir/${AppConfig.linuxAppId}.desktop');
      final content = _content();
      if (file.existsSync() && await file.readAsString() == content) return;
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } on Object catch (error, stackTrace) {
      // Without the entry only the dock icon and badge are lost.
      appTalker.handle(error, stackTrace, 'Desktop entry: write failed');
    }
  }

  String _content() {
    // The bundle's icon, installed by linux/CMakeLists.txt.
    final icon = '${File(_executable).parent.path}/data/app_icon.png';
    return [
      '[Desktop Entry]',
      'Type=Application',
      'Name=${AppConfig.appName}',
      'Exec=${_quoted(_executable)}',
      'Icon=${icon.replaceAll(r'\', r'\\')}',
      'Terminal=false',
      'Categories=Office;',
      'StartupWMClass=${AppConfig.linuxAppId}',
      '',
    ].join('\n');
  }

  /// [path] as one Exec argument. The spec unescapes string values before
  /// it unquotes arguments, so a backslash is escaped twice over.
  static String _quoted(String path) {
    final quoted = path.replaceAllMapped(
      RegExp(r'["`$\\]'),
      (m) => '\\${m[0]}',
    );
    return '"${quoted.replaceAll(r'\', r'\\').replaceAll('%', '%%')}"';
  }
}
