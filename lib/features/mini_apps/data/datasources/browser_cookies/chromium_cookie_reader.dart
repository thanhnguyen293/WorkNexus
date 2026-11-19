import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../domain/entities/browser_cookie.dart';
import '../../../domain/value_objects/cookie_browser.dart';
import '../../../domain/value_objects/cookie_same_site.dart';
import 'chromium_cookie_crypto.dart';
import 'chromium_gcm_cookie_crypto.dart';
import 'chromium_installs.dart';
import 'join_path.dart';
import 'sqlite_snapshot.dart';
import 'windows_dpapi.dart';

/// A Chromium profile: its folder and the name the browser shows for it.
typedef ChromiumProfile = ({String path, String name});

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

/// The cookies of Chromium browsers on macOS and Windows.
///
/// On macOS the key comes from the keychain, which asks the user once; it is
/// then kept for the session. On Windows it sits DPAPI-protected in the
/// browser's `Local State`; Chrome's own cookies there are app-bound (since
/// Chrome 127) and only Chrome can decrypt them, which [read] reports as an
/// [AppBoundEncryptionException].
class ChromiumCookieReader {
  ChromiumCookieReader({
    Map<String, String>? environment,
    String? os,
    this._run = runKilledAfterTimeout,
    this._unprotect = windowsUnprotect,
    this._keychainTimeout = const Duration(seconds: 90),
  }) : _environment = environment ?? Platform.environment,
       _os = os ?? Platform.operatingSystem;

  final Map<String, String> _environment;
  final String _os;
  final RunCommand _run;
  final Unprotect _unprotect;

  /// How long the keychain prompt is waited on. It can open where the user
  /// does not see it (on another Space while the app is full screen, behind
  /// the window), and the import would otherwise wait on it for good.
  final Duration _keychainTimeout;

  /// Keys by keychain item (macOS) or data folder (Windows).
  final _keys = <String, CookieDecrypter>{};

  /// The folders [browser] keeps its data in here, each release channel's.
  Future<List<String>> _dataDirs(CookieBrowser browser) async => [
    ...chromiumDataDirs(browser, os: _os, environment: _environment),
    if (browser == CookieBrowser.arc && _os == 'windows')
      ...await _arcOnWindows(),
  ];

  Future<List<String>> _arcOnWindows() async {
    final local = _environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return const [];
    final packages = Directory(joinPath([local, 'Packages']));
    if (!await packages.exists()) return const [];
    return [
      await for (final entry in packages.list())
        if (entry is Directory &&
            _name(entry.path).startsWith(arcWindowsPackagePrefix))
          joinPath([entry.path, arcWindowsDataDir]),
    ];
  }

  static String _name(String path) => path.split(RegExp(r'[\\/]')).last;

  /// [browser]'s profiles that have cookies, named as it names them.
  Future<List<ChromiumProfile>> profiles(CookieBrowser browser) async {
    final found = <ChromiumProfile>[];
    for (final dir in await _dataDirs(browser)) {
      if (!await Directory(dir).exists()) continue;
      final names = await _profileNames(dir);
      // Opera keeps its one profile's files right in its data folder, whose
      // subfolders (`Network`, …) are then not profiles.
      if (await _cookieFile(dir) != null) {
        found.add((path: dir, name: names[_name(dir)] ?? 'Default'));
        continue;
      }
      await for (final entry in Directory(dir).list()) {
        if (entry is! Directory) continue;
        if (await _cookieFile(entry.path) == null) continue;
        final folder = _name(entry.path);
        found.add((path: entry.path, name: names[folder] ?? folder));
      }
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
  /// [KeychainDeniedException] when the keychain refuses the password, and an
  /// [AppBoundEncryptionException] when only the browser can decrypt them.
  Future<List<BrowserCookie>> read(
    CookieBrowser browser,
    String profilePath,
  ) async {
    final file = await _cookieFile(profilePath);
    if (file == null) {
      throw FileSystemException('No cookies', profilePath);
    }
    final crypto = await _keyFor(browser, profilePath);
    // Decrypting thousands of values is too slow for the UI isolate.
    final read = await Isolate.run(() => _readFile(file, crypto));
    if (read.cookies.isEmpty && read.appBound > 0) {
      throw AppBoundEncryptionException(browser);
    }
    return read.cookies;
  }

  static Future<({List<BrowserCookie> cookies, int appBound})> _readFile(
    String file,
    CookieDecrypter crypto,
  ) => readSqliteSnapshot(file, (db) {
    final version = db.select("SELECT value FROM meta WHERE key = 'version'");
    final hasDomainHash =
        (int.tryParse('${version.firstOrNull?['value']}') ?? 0) >= 24;
    final rows = db.select(
      'SELECT host_key, name, value, encrypted_value, path, '
      'expires_utc, is_secure, is_httponly, samesite FROM cookies',
    );
    final cookies = [
      for (final row in rows)
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
    final appBound = rows
        .where((row) => _isAppBound(row['encrypted_value']))
        .length;
    return (cookies: cookies, appBound: appBound);
  });

  /// A `v20` value: encrypted with Chrome's app-bound key on Windows.
  static bool _isAppBound(Object? encrypted) =>
      encrypted is Uint8List &&
      encrypted.length > 3 &&
      encrypted[0] == 0x76 && // v
      encrypted[1] == 0x32 && // 2
      encrypted[2] == 0x30; // 0

  static String? _value(
    Object? plain,
    Object? encrypted,
    CookieDecrypter crypto,
    bool hasDomainHash,
  ) {
    if (plain is String && plain.isNotEmpty) return plain;
    if (encrypted is! Uint8List || encrypted.isEmpty) return null;
    return crypto.decrypt(encrypted, hasDomainHash: hasDomainHash);
  }

  Future<CookieDecrypter> _keyFor(
    CookieBrowser browser,
    String profilePath,
  ) async {
    if (_os == 'windows') {
      // Opera's profile is its data folder; others' sit one level down.
      final dataDir =
          await File(joinPath([profilePath, 'Local State'])).exists()
          ? profilePath
          : Directory(profilePath).parent.path;
      return _keys[dataDir] ??= await _windowsKey(dataDir);
    }
    final service = chromiumKeychainService(browser);
    if (service == null) throw ArgumentError.value(browser, 'browser');
    return _keys[service] ??= await _keychainKey(service);
  }

  Future<CookieDecrypter> _windowsKey(String dataDir) async {
    final state = jsonDecode(
      await File(joinPath([dataDir, 'Local State'])).readAsString(),
    );
    final encoded = switch (state) {
      {'os_crypt': {'encrypted_key': final String key}} => key,
      _ => null,
    };
    final blob = encoded == null ? null : base64.decode(encoded);
    // The key is stored as `DPAPI` followed by the protected bytes.
    if (blob == null ||
        blob.length <= 5 ||
        ascii.decode(blob.sublist(0, 5), allowInvalid: true) != 'DPAPI') {
      throw FormatException('No cookie key in Local State', dataDir);
    }
    final key = _unprotect(Uint8List.sublistView(blob, 5));
    if (key == null) {
      throw const FormatException('Windows refused the cookie key');
    }
    return ChromiumGcmCookieCrypto(key);
  }

  Future<CookieDecrypter> _keychainKey(String service) async {
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

/// The browser encrypts its cookies with a key only it can get (Chrome's
/// app-bound encryption on Windows).
class AppBoundEncryptionException implements Exception {
  const AppBoundEncryptionException(this.browser);

  final CookieBrowser browser;

  @override
  String toString() => 'AppBoundEncryptionException(${browser.name})';
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
