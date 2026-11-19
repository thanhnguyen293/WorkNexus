import 'dart:io';

/// An app's `.desktop` launcher entry: [id] is the file name without
/// `.desktop` (what `gtk-launch` takes), [wmClass] the X11 window class its
/// windows carry.
typedef DesktopApp = ({String id, String name, String wmClass});

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
      if (line == 'NoDisplay=true' || line == 'Hidden=true') hidden = true;
      if (line.startsWith('Type=') && line.trim() != 'Type=Application') {
        hidden = true;
      }
    }
    if (hidden || name == null || name.isEmpty) return null;
    final base = file.uri.pathSegments.last;
    final id = base.substring(0, base.length - '.desktop'.length);
    return (id: id, name: name, wmClass: wmClass ?? id);
  }
}
