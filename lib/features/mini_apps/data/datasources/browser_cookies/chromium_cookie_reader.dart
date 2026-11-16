import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../domain/entities/browser_cookie.dart';
import '../../../domain/value_objects/cookie_browser.dart';
import '../../../domain/value_objects/cookie_same_site.dart';
import 'chromium_cookie_crypto.dart';
import 'join_path.dart';
import 'sqlite_snapshot.dart';

/// A Chromium profile: its folder and the name the browser shows for it.
typedef ChromiumProfile = ({String path, String name});

/// Where a Chromium browser keeps its data on macOS, and the keychain item
/// holding its cookie password.
typedef _Install = ({String dataDir, String keychainService});

/// Runs a command, giving up after [timeout] with a [TimeoutException].
typedef RunCommand =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
      Duration timeout,
    );

/// [RunCommand] on a real process, which is killed when the time is up.
/// Its stdin is closed at once, so a tool that falls back to asking on the
/// terminal fails instead of waiting on it.
Future<ProcessResult> runKilledAfterTimeout(
  String executable,
  List<String> arguments,
  Duration timeout,
) async {
  final process = await Process.start(executable, arguments);
  unawaited(process.stdin.close());
  final out = process.stdout.transform(systemEncoding.decoder).join();
  final err = process.stderr.transform(systemEncoding.decoder).join();
  final code = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill();
      throw TimeoutException('$executable did not finish', timeout);
    },
  );
  return ProcessResult(process.pid, code, await out, await err);
}

/// The cookies of Chromium browsers on macOS. Reading the keychain password
/// makes macOS ask the user once; the key is then kept for the session.
///
/// Not offered on Windows: since Chrome 127 its cookies there are bound to
/// Chrome itself and no other app can decrypt them.
class ChromiumCookieReader {
  ChromiumCookieReader({
    this._home,
    this._run = runKilledAfterTimeout,
    this._keychainTimeout = const Duration(seconds: 90),
  });

  final String? _home;
  final RunCommand _run;

  /// How long the keychain prompt is waited on. It can open where the user
  /// does not see it (on another Space while the app is full screen, behind
  /// the window), and the import would otherwise wait on it for good.
  final Duration _keychainTimeout;
  final _keys = <CookieBrowser, ChromiumCookieCrypto>{};

  static _Install? _install(CookieBrowser browser) => switch (browser) {
    CookieBrowser.chrome => (
      dataDir: 'Google/Chrome',
      keychainService: 'Chrome Safe Storage',
    ),
    CookieBrowser.edge => (
      dataDir: 'Microsoft Edge',
      keychainService: 'Microsoft Edge Safe Storage',
    ),
    CookieBrowser.brave => (
      dataDir: 'BraveSoftware/Brave-Browser',
      keychainService: 'Brave Safe Storage',
    ),
    CookieBrowser.arc => (
      dataDir: 'Arc/User Data',
      keychainService: 'Arc Safe Storage',
    ),
    CookieBrowser.firefox || CookieBrowser.safari => null,
  };

  String? _dataDir(CookieBrowser browser) {
    final install = _install(browser);
    if (install == null || !Platform.isMacOS) return null;
    final home = _home ?? Platform.environment['HOME'] ?? '';
    return joinPath([home, 'Library/Application Support', install.dataDir]);
  }

  /// [browser]'s profiles that have cookies, named as it names them.
  Future<List<ChromiumProfile>> profiles(CookieBrowser browser) async {
    final dir = _dataDir(browser);
    if (dir == null || !await Directory(dir).exists()) return const [];
    final names = await _profileNames(dir);
    final found = <ChromiumProfile>[];
    await for (final entry in Directory(dir).list()) {
      if (entry is! Directory) continue;
      if (await _cookieFile(entry.path) == null) continue;
      final folder = entry.path.split(Platform.pathSeparator).last;
      found.add((path: entry.path, name: names[folder] ?? folder));
    }
    return found..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The names `Local State` gives each profile folder.
  static Future<Map<String, String>> _profileNames(String dataDir) async {
    try {
      final state = jsonDecode(
        await File(joinPath([dataDir, 'Local State'])).readAsString(),
      );
      final cache = switch (state) {
        {'profile': {'info_cache': final Map<dynamic, dynamic> cache}} => cache,
        _ => null,
      };
      return {
        if (cache is Map)
          for (final MapEntry(:key, :value) in cache.entries)
            if (value is Map && value['name'] is String)
              '$key': value['name'] as String,
      };
    } on Object {
      // Without the names, the folders' own names do.
      return const {};
    }
  }

  /// The profile's cookie database: newer versions keep it under `Network`.
  static Future<String?> _cookieFile(String profile) async {
    for (final path in [
      joinPath([profile, 'Network', 'Cookies']),
      joinPath([profile, 'Cookies']),
    ]) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  /// Every cookie in the profile at [profilePath]. Throws a
  /// [KeychainDeniedException] when the keychain refuses the password.
  Future<List<BrowserCookie>> read(
    CookieBrowser browser,
    String profilePath,
  ) async {
    final file = await _cookieFile(profilePath);
    if (file == null) {
      throw FileSystemException('No cookies', profilePath);
    }
    final crypto = _keys[browser] ??= await _keyFor(browser);
    // Decrypting thousands of values is too slow for the UI isolate.
    return Isolate.run(() => _readFile(file, crypto));
  }

  static Future<List<BrowserCookie>> _readFile(
    String file,
    ChromiumCookieCrypto crypto,
  ) => readSqliteSnapshot(file, (db) {
    final version = db.select("SELECT value FROM meta WHERE key = 'version'");
    final hasDomainHash =
        (int.tryParse('${version.firstOrNull?['value']}') ?? 0) >= 24;
    return [
      for (final row in db.select(
        'SELECT host_key, name, value, encrypted_value, path, '
        'expires_utc, is_secure, is_httponly, samesite FROM cookies',
      ))
        if (_value(row['value'], row['encrypted_value'], crypto, hasDomainHash)
            case final value?)
          BrowserCookie(
            name: row['name'] as String,
            value: value,
            domain: row['host_key'] as String,
            path: row['path'] as String? ?? '/',
            expires: chromiumExpiry(row['expires_utc'] as int?),
            secure: row['is_secure'] == 1,
            httpOnly: row['is_httponly'] == 1,
            sameSite: switch (row['samesite']) {
              0 => CookieSameSite.none,
              1 => CookieSameSite.lax,
              2 => CookieSameSite.strict,
              _ => CookieSameSite.unspecified,
            },
          ),
    ];
  });

  static String? _value(
    Object? plain,
    Object? encrypted,
    ChromiumCookieCrypto crypto,
    bool hasDomainHash,
  ) {
    if (plain is String && plain.isNotEmpty) return plain;
    if (encrypted is! Uint8List || encrypted.isEmpty) return null;
    return crypto.decrypt(encrypted, hasDomainHash: hasDomainHash);
  }

  Future<ChromiumCookieCrypto> _keyFor(CookieBrowser browser) async {
    final service = _install(browser)?.keychainService;
    if (service == null) throw ArgumentError.value(browser, 'browser');
    final ProcessResult result;
    try {
      result = await _run('security', [
        'find-generic-password',
        '-w',
        '-s',
        service,
      ], _keychainTimeout);
    } on TimeoutException {
      throw KeychainTimeoutException(service);
    }
    if (result.exitCode != 0) throw KeychainDeniedException(service);
    return ChromiumCookieCrypto.fromPassword((result.stdout as String).trim());
  }
}

/// The keychain did not give out a browser's cookie password: the user
/// refused, or it is not there.
class KeychainDeniedException implements Exception {
  const KeychainDeniedException(this.service);

  final String service;

  @override
  String toString() => 'KeychainDeniedException($service)';
}

/// The keychain prompt for a browser's cookie password went unanswered.
class KeychainTimeoutException implements Exception {
  const KeychainTimeoutException(this.service);

  final String service;

  @override
  String toString() => 'KeychainTimeoutException($service)';
}

/// Chromium counts microseconds from 1601; zero is a session cookie.
DateTime? chromiumExpiry(int? value) {
  if (value == null || value <= 0) return null;
  const from1601To1970 = 11644473600000000;
  return DateTime.fromMicrosecondsSinceEpoch(
    value - from1601To1970,
    isUtc: true,
  );
}
