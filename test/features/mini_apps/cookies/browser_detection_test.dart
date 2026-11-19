import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_gcm_cookie_crypto.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_installs.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/firefox_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';

final _key = Uint8List.fromList(List.generate(32, (i) => i));

/// Encrypts [plain] the way Chromium on Windows does (`v10` + AES-256-GCM).
Uint8List _gcmEncrypt(List<int> plain) {
  final nonce = Uint8List.fromList(List.filled(12, 7));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)));
  return Uint8List.fromList([
    ...ascii.encode('v10'),
    ...nonce,
    ...cipher.process(Uint8List.fromList(plain)),
  ]);
}

void _cookieDb(String path, List<Object?> encryptedValues) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  db
    ..execute('CREATE TABLE meta (key TEXT, value TEXT)')
    ..execute("INSERT INTO meta VALUES ('version', '24')")
    ..execute(
      'CREATE TABLE cookies (host_key TEXT, name TEXT, value TEXT, '
      'encrypted_value BLOB, path TEXT, expires_utc INTEGER, '
      'is_secure INTEGER, is_httponly INTEGER, samesite INTEGER)',
    );
  for (final value in encryptedValues) {
    db.execute('INSERT INTO cookies VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
      '.work.io',
      'sid',
      '',
      value,
      '/',
      0,
      1,
      1,
      1,
    ]);
  }
  db.close();
}

void _touch(String path) => File(path)
  ..parent.createSync(recursive: true)
  ..writeAsStringSync('');

void main() {
  late Directory tmp;
  late String sep;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('browser_detection');
    sep = Platform.pathSeparator;
  });
  tearDown(() => tmp.delete(recursive: true));

  group('chromiumDataDirs', () {
    test('every channel under Application Support on macOS', () {
      final dirs = chromiumDataDirs(
        CookieBrowser.chrome,
        os: 'macos',
        environment: {'HOME': '/u'},
      );
      expect(dirs, [
        for (final d in [
          'Google/Chrome',
          'Google/Chrome Beta',
          'Google/Chrome Dev',
          'Google/Chrome Canary',
        ])
          '/u${sep}Library/Application Support$sep$d',
      ]);
    });

    test('User Data under %LOCALAPPDATA% on Windows, Opera in %APPDATA%', () {
      const env = {'LOCALAPPDATA': r'C:\L', 'APPDATA': r'C:\R'};
      expect(
        chromiumDataDirs(CookieBrowser.edge, os: 'windows', environment: env),
        contains('C:\\L${sep}Microsoft/Edge/User Data'),
      );
      expect(
        chromiumDataDirs(CookieBrowser.opera, os: 'windows', environment: env),
        ['C:\\R${sep}Opera Software/Opera Stable'],
      );
      expect(
        chromiumDataDirs(CookieBrowser.chrome, os: 'windows', environment: {}),
        isEmpty,
      );
    });
  });

  group('ChromiumCookieReader on Windows', () {
    late Map<String, String> env;
    late String local;

    setUp(() {
      local = '${tmp.path}${sep}Local';
      env = {'LOCALAPPDATA': local, 'APPDATA': '${tmp.path}${sep}Roaming'};
    });

    test('finds every profile, old and new cookie locations', () async {
      final chrome = '$local/Google/Chrome/User Data';
      _touch('$chrome/Default/Network/Cookies');
      _touch('$chrome/Profile 1/Cookies');
      Directory('$chrome/Profile 2').createSync(); // no cookies: skipped
      File('$chrome/Local State').writeAsStringSync(
        jsonEncode({
          'profile': {
            'info_cache': {
              'Default': {'name': 'Personal'},
              'Profile 1': {'name': 'Work'},
            },
          },
        }),
      );
      _touch('$local/Microsoft/Edge Beta/User Data/Default/Network/Cookies');
      _touch('${env['APPDATA']}/Opera Software/Opera Stable/Network/Cookies');
      _touch(
        '$local/Packages/TheBrowserCompany.Arc_ttt1ap7aakyb4/'
        'LocalCache/Local/Arc/User Data/Default/Network/Cookies',
      );
      final reader = ChromiumCookieReader(environment: env, os: 'windows');

      final chromeProfiles = await reader.profiles(CookieBrowser.chrome);
      expect([for (final p in chromeProfiles) p.name], ['Personal', 'Work']);
      expect(await reader.profiles(CookieBrowser.edge), hasLength(1));
      expect(await reader.profiles(CookieBrowser.opera), hasLength(1));
      expect(await reader.profiles(CookieBrowser.arc), hasLength(1));
      expect(await reader.profiles(CookieBrowser.brave), isEmpty);
    });

    String withKey(String dataDir) {
      File('$dataDir/Local State')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'os_crypt': {
              'encrypted_key': base64.encode([
                ...ascii.encode('DPAPI'),
                ..._key,
              ]),
            },
          }),
        );
      return dataDir;
    }

    test('decrypts v10 values with the DPAPI-protected key', () async {
      final data = withKey('$local/Microsoft/Edge/User Data');
      _cookieDb('$data/Default/Network/Cookies', [
        _gcmEncrypt([...List.filled(32, 0), ...utf8.encode('abc')]),
      ]);
      final reader = ChromiumCookieReader(
        environment: env,
        os: 'windows',
        unprotect: (blob) => blob, // the fake "DPAPI" hands the key back
      );

      final profile = (await reader.profiles(CookieBrowser.edge)).single;
      final cookies = await reader.read(CookieBrowser.edge, profile.path);

      expect(cookies.single.value, 'abc');
    });

    test('only app-bound values is an AppBoundEncryptionException', () async {
      final data = withKey('$local/Google/Chrome/User Data');
      _cookieDb('$data/Default/Network/Cookies', [
        Uint8List.fromList([...ascii.encode('v20'), ...List.filled(40, 1)]),
      ]);
      final reader = ChromiumCookieReader(
        environment: env,
        os: 'windows',
        unprotect: (blob) => blob,
      );

      await expectLater(
        reader.read(CookieBrowser.chrome, '$data/Default'),
        throwsA(isA<AppBoundEncryptionException>()),
      );
    });
  });

  test('ChromiumGcmCookieCrypto refuses a wrong key', () {
    final value = _gcmEncrypt(utf8.encode('abc'));
    final wrong = ChromiumGcmCookieCrypto(Uint8List(32));
    expect(wrong.decrypt(value, hasDomainHash: false), isNull);
    expect(
      ChromiumGcmCookieCrypto(_key).decrypt(value, hasDomainHash: false),
      'abc',
    );
  });

  group('Firefox', () {
    test('roots cover the Store build on Windows and Snap/XDG on Linux', () {
      expect(
        firefoxRoots(
          os: 'windows',
          environment: {'APPDATA': 'R', 'LOCALAPPDATA': 'L'},
        ),
        [
          'R${sep}Mozilla/Firefox',
          'L${sep}Packages/Mozilla.Firefox_n80bbvh6b1yt2$sep'
              'LocalCache/Roaming/Mozilla/Firefox',
        ],
      );
      expect(
        firefoxRoots(os: 'linux', environment: {'HOME': 'h'}),
        containsAll([
          'h$sep.mozilla/firefox',
          'h${sep}snap/firefox/common/.mozilla/firefox',
          'h$sep.config${sep}mozilla/firefox',
        ]),
      );
    });

    test('profiles come from every root that has them', () async {
      final store = '${tmp.path}${sep}store';
      File('$store/profiles.ini')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('[Profile0]\nName=main\nIsRelative=1\nPath=p\n');
      _touch('$store/p/cookies.sqlite');
      final reader = FirefoxCookieReader(
        roots: ['${tmp.path}${sep}missing', store],
      );

      final profiles = await reader.profiles();

      expect(profiles.single.name, 'main');
    });
  });
}
