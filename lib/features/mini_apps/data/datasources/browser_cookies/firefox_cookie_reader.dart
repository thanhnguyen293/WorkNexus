import 'dart:io';

import '../../../domain/entities/browser_cookie.dart';
import '../../../domain/value_objects/cookie_same_site.dart';
import 'join_path.dart';
import 'sqlite_snapshot.dart';

/// A Firefox profile: its folder and the name it goes by.
typedef FirefoxProfile = ({String path, String name});

/// Firefox's cookies, kept unencrypted in each profile's `cookies.sqlite`.
class FirefoxCookieReader {
  const FirefoxCookieReader({this._roots});

  final List<String>? _roots;

  /// The `profiles.ini` profiles that have cookies, from every place Firefox
  /// may keep them here.
  Future<List<FirefoxProfile>> profiles() async {
    final roots =
        _roots ??
        firefoxRoots(
          os: Platform.operatingSystem,
          environment: Platform.environment,
        );
    final found = <FirefoxProfile>[];
    for (final root in roots) {
      final ini = File(joinPath([root, 'profiles.ini']));
      if (!await ini.exists()) continue;
      for (final section in parseProfilesIni(await ini.readAsString())) {
        final path = section.relative
            ? joinPath([root, section.path])
            : section.path;
        if (await File(joinPath([path, 'cookies.sqlite'])).exists()) {
          found.add((path: path, name: section.name));
        }
      }
    }
    return found;
  }

  Future<List<BrowserCookie>> read(String profilePath) => readSqliteSnapshot(
    joinPath([profilePath, 'cookies.sqlite']),
    (db) => [
      for (final row in db.select(
        'SELECT name, value, host, path, expiry, isSecure, isHttpOnly, '
        'sameSite FROM moz_cookies',
      ))
        BrowserCookie(
          name: row['name'] as String,
          value: row['value'] as String? ?? '',
          domain: row['host'] as String,
          path: row['path'] as String? ?? '/',
          expires: firefoxExpiry(row['expiry'] as int?),
          secure: row['isSecure'] == 1,
          httpOnly: row['isHttpOnly'] == 1,
          sameSite: switch (row['sameSite']) {
            0 => CookieSameSite.none,
            1 => CookieSameSite.lax,
            2 => CookieSameSite.strict,
            _ => CookieSameSite.unspecified,
          },
        ),
    ],
  );
}

/// Where Firefox may keep its profiles on [os] (as `Platform.operatingSystem`
/// names it): its classic folder, and those of the Microsoft Store, Snap and
/// Flatpak builds and of Firefox's newer XDG layout on Linux.
List<String> firefoxRoots({
  required String os,
  required Map<String, String> environment,
}) {
  String? dir(String name) {
    final value = environment[name];
    return value == null || value.isEmpty ? null : value;
  }

  final home = dir('HOME');
  switch (os) {
    case 'macos':
      return [
        if (home != null)
          joinPath([home, 'Library/Application Support/Firefox']),
      ];
    case 'windows':
      final roaming = dir('APPDATA');
      final local = dir('LOCALAPPDATA');
      return [
        if (roaming != null) joinPath([roaming, 'Mozilla/Firefox']),
        if (local != null)
          joinPath([
            local,
            'Packages/Mozilla.Firefox_n80bbvh6b1yt2',
            'LocalCache/Roaming/Mozilla/Firefox',
          ]),
      ];
    case 'linux':
      final config =
          dir('XDG_CONFIG_HOME') ??
          (home == null ? null : joinPath([home, '.config']));
      return [
        if (home != null) ...[
          joinPath([home, '.mozilla/firefox']),
          joinPath([home, 'snap/firefox/common/.mozilla/firefox']),
          joinPath([home, '.var/app/org.mozilla.firefox/.mozilla/firefox']),
        ],
        if (config != null) joinPath([config, 'mozilla/firefox']),
      ];
  }
  return const [];
}

/// One `[ProfileN]` section of `profiles.ini`.
typedef FirefoxIniProfile = ({String name, String path, bool relative});

/// The profiles `profiles.ini` lists.
List<FirefoxIniProfile> parseProfilesIni(String text) {
  final found = <FirefoxIniProfile>[];
  Map<String, String>? section;
  void flush() {
    final path = section?['Path'];
    if (path != null) {
      found.add((
        name: section?['Name'] ?? path.split(RegExp(r'[\\/]')).last,
        path: path,
        relative: section?['IsRelative'] != '0',
      ));
    }
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      flush();
      section = line.startsWith('[Profile') ? {} : null;
    } else if (section != null && line.contains('=')) {
      final at = line.indexOf('=');
      section[line.substring(0, at)] = line.substring(at + 1);
    }
  }
  flush();
  return found;
}

/// Firefox wrote the expiry in seconds and, since version 136, writes it in
/// milliseconds; a value past the year 5000 in seconds can only be the latter.
/// Zero or none is a session cookie.
DateTime? firefoxExpiry(int? value) {
  if (value == null || value <= 0) return null;
  final ms = value > 100000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
