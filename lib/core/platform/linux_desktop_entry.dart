import 'dart:io';

import '../config/app_config.dart';
import '../debug/app_talker.dart';
import 'app_image.dart';

/// Writes the app's `.desktop` entry into the user's applications folder on
/// launch, as Telegram Desktop does. The Linux release is a bare tarball with
/// no installer, and without an entry a dock shows neither the app's icon nor
/// its unread badge: it ties the window to the entry by
/// [AppConfig.linuxAppId].
///
/// Run from an AppImage, the entry starts the `.AppImage` file rather than the
/// binary, and the icon is copied out of the image: both sit in a mount that
/// is gone once the app exits.
class LinuxDesktopEntry {
  LinuxDesktopEntry({
    String? executable,
    String? applicationsDir,
    String? appImage,
  }) : _executable = executable ?? Platform.resolvedExecutable,
       _applicationsDir = applicationsDir ?? _defaultApplicationsDir(),
       _appImage = appImage ?? runningAppImage();

  final String _executable;
  final String _applicationsDir;
  final String? _appImage;

  static String _defaultApplicationsDir() {
    final env = Platform.environment;
    final dataHome = env['XDG_DATA_HOME'];
    final base = dataHome != null && dataHome.isNotEmpty
        ? dataHome
        : '${env['HOME']}/.local/share';
    return '$base/applications';
  }

  /// The bundle's icon, installed by linux/CMakeLists.txt.
  String get _bundledIcon =>
      '${File(_executable).parent.path}/data/app_icon.png';

  /// Where an AppImage's icon is copied: the user's icon theme, beside the
  /// applications folder.
  String get _copiedIcon =>
      '${Directory(_applicationsDir).parent.path}/icons/hicolor/256x256/apps/'
      '${AppConfig.linuxAppId}.png';

  /// Writes the entry, or rewrites it when the app has moved since; leaves an
  /// up-to-date one untouched.
  Future<void> ensureInstalled() async {
    try {
      if (_appImage != null) await _copyIcon();
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

  /// Copies the icon out of the AppImage when the copy is missing or differs.
  Future<void> _copyIcon() async {
    final source = File(_bundledIcon);
    final target = File(_copiedIcon);
    if (target.existsSync() && target.lengthSync() == source.lengthSync()) {
      return;
    }
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  String _content() {
    final icon = _appImage == null ? _bundledIcon : _copiedIcon;
    return [
      '[Desktop Entry]',
      'Type=Application',
      'Name=${AppConfig.appName}',
      'Exec=${_quoted(_appImage ?? _executable)}',
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
