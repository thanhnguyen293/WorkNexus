import 'dart:io';

import '../../../domain/entities/browser_cookie.dart';
import '../../../domain/value_objects/cookie_same_site.dart';
import 'join_path.dart';
import 'sqlite_snapshot.dart';

/// A Firefox profile: its folder and the name it goes by.
typedef FirefoxProfile = ({String path, String name});

/// Firefox's cookies, kept unencrypted in each profile's `cookies.sqlite`.
class FirefoxCookieReader {
  const FirefoxCookieReader({this._root});

  final String? _root;

  /// Where Firefox keeps its profiles on this system.
  static String? defaultRoot() {
    final env = Platform.environment;
    if (Platform.isMacOS) {
      return joinPath([
        env['HOME'] ?? '',
        'Library/Application Support/Firefox',
      ]);
    }
    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      return appData == null ? null : joinPath([appData, 'Mozilla', 'Firefox']);
    }
    if (Platform.isLinux) {
      return joinPath([env['HOME'] ?? '', '.mozilla/firefox']);
    }
    return null;
  }

  /// The profiles listed in `profiles.ini` that have cookies.
  Future<List<FirefoxProfile>> profiles() async {
    final root = _root ?? defaultRoot();
    if (root == null) return const [];
    final ini = File(joinPath([root, 'profiles.ini']));
    if (!await ini.exists()) return const [];
    final found = <FirefoxProfile>[];
    for (final section in parseProfilesIni(await ini.readAsString())) {
      final path = section.relative
          ? joinPath([root, section.path])
          : section.path;
      if (await File(joinPath([path, 'cookies.sqlite'])).exists()) {
        found.add((path: path, name: section.name));
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
