import 'dart:io';

/// An app's `.desktop` launcher entry: [id] is the file name without
/// `.desktop` (what `gtk-launch` takes), [wmClass] the X11 window class its
/// windows carry, [icon] its `Icon=` (a theme name or a file path).
typedef DesktopApp = ({String id, String name, String wmClass, String? icon});

/// Reads the installed apps from the freedesktop launcher entries.
class LinuxDesktopApps {
  const LinuxDesktopApps();

  Future<List<DesktopApp>> list() async {
    final byId = <String, DesktopApp>{};
    for (final dir in _dirs()) {
      final folder = Directory(dir);
      if (!await folder.exists()) continue;
      await for (final entity in folder.list()) {
        if (entity is! File || !entity.path.endsWith('.desktop')) continue;
        final app = await _read(entity);
        // Earlier folders (the user's own) win over system-wide entries.
        if (app != null) byId.putIfAbsent(app.id, () => app);
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<DesktopApp?> find(String id) async {
    for (final dir in _dirs()) {
      final file = File('$dir/$id.desktop');
      if (await file.exists()) return _read(file);
    }
    return null;
  }

  static List<String> _dirs() {
    final home = Platform.environment['HOME'] ?? '';
    final dataDirs =
        (Platform.environment['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
            .split(':');
    return [
      '$home/.local/share/applications',
      for (final d in dataDirs)
        if (d.isNotEmpty) '$d/applications',
      '/var/lib/snapd/desktop/applications',
      '/var/lib/flatpak/exports/share/applications',
    ];
  }

  static Future<DesktopApp?> _read(File file) async {
    String? name;
    String? wmClass;
    String? icon;
    var hidden = false;
    var inEntry = false;
    for (final line in await file.readAsLines()) {
      if (line.startsWith('[')) {
        // Only the main section; actions have their own Name= keys.
        inEntry = line.trim() == '[Desktop Entry]';
        continue;
      }
      if (!inEntry) continue;
      if (line.startsWith('Name=')) name ??= line.substring(5).trim();
      if (line.startsWith('StartupWMClass=')) {
        wmClass = line.substring(15).trim();
      }
      if (line.startsWith('Icon=')) icon = line.substring(5).trim();
      if (line == 'NoDisplay=true' || line == 'Hidden=true') hidden = true;
      if (line.startsWith('Type=') && line.trim() != 'Type=Application') {
        hidden = true;
      }
    }
    if (hidden || name == null || name.isEmpty) return null;
    final base = file.uri.pathSegments.last;
    final id = base.substring(0, base.length - '.desktop'.length);
    return (id: id, name: name, wmClass: wmClass ?? id, icon: icon);
  }

  /// The PNG file of [app]'s icon: its `Icon=` path, else the theme name
  /// looked up in the hicolor theme and pixmaps. SVG-only icons are skipped
  /// (Flutter cannot decode them from bytes).
  Future<File?> iconFile(DesktopApp app) async {
    final icon = app.icon;
    if (icon == null || icon.isEmpty) return null;
    if (icon.startsWith('/')) {
      final file = File(icon);
      return icon.endsWith('.png') && await file.exists() ? file : null;
    }
    final home = Platform.environment['HOME'] ?? '';
    final roots = [
      '$home/.local/share/icons/hicolor',
      '/usr/share/icons/hicolor',
      '/var/lib/flatpak/exports/share/icons/hicolor',
    ];
    for (final root in roots) {
      for (final size in const ['64x64', '48x48', '128x128', '32x32']) {
        final file = File('$root/$size/apps/$icon.png');
        if (await file.exists()) return file;
      }
    }
    final pixmap = File('/usr/share/pixmaps/$icon.png');
    return await pixmap.exists() ? pixmap : null;
  }
}
