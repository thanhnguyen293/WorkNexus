import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_cookie_crypto.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/firefox_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/safari_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_same_site.dart';

/// Encrypts [plain] the way Chromium on macOS does, for [password].
Uint8List _chromiumEncrypt(String password, List<int> plain) {
  // Derived here on its own, as Chromium documents it, to check the reader's.
  final derived =
      (PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
            ..init(Pbkdf2Parameters(utf8.encode('saltysalt'), 1003, 16)))
          .process(utf8.encode(password));
  final pad = 16 - plain.length % 16;
  final padded = Uint8List.fromList([...plain, ...List.filled(pad, pad)]);
  final cipher = CBCBlockCipher(AESEngine())
    ..init(
      true,
      ParametersWithIV(
        KeyParameter(derived),
        Uint8List.fromList(List.filled(16, 0x20)),
      ),
    );
  final out = Uint8List(padded.length);
  for (var at = 0; at < padded.length; at += 16) {
    cipher.processBlock(padded, at, out, at);
  }
  return Uint8List.fromList([...ascii.encode('v10'), ...out]);
}

void main() {
  late Directory tmp;

  setUp(
    () async => tmp = await Directory.systemTemp.createTemp('cookies_test'),
  );
  tearDown(() => tmp.delete(recursive: true));

  group('ChromiumCookieCrypto', () {
    test('decrypts a v10 value, dropping the domain hash from v24 on', () {
      final crypto = ChromiumCookieCrypto.fromPassword('secret');
      final hash = SHA256Digest().process(utf8.encode('.work.io'));
      final withHash = _chromiumEncrypt('secret', [
        ...hash,
        ...utf8.encode('token'),
      ]);
      final plain = _chromiumEncrypt('secret', utf8.encode('token'));

      expect(crypto.decrypt(withHash, hasDomainHash: true), 'token');
      expect(crypto.decrypt(plain, hasDomainHash: false), 'token');
    });

    test('gives up on another scheme or a wrong key', () {
      final other = ChromiumCookieCrypto.fromPassword('other');
      final value = _chromiumEncrypt('secret', utf8.encode('token'));

      expect(
        ChromiumCookieCrypto.fromPassword('secret').decrypt(
          Uint8List.fromList(ascii.encode('v20xxxxxxxxxxxxxxxx')),
          hasDomainHash: false,
        ),
        isNull,
      );
      expect(other.decrypt(value, hasDomainHash: false), isNot('token'));
    });
  });

  group('ChromiumCookieReader', () {
    test(
      'reads and decrypts a profile, asking the keychain once',
      () async {
        final profile = Directory(
          '${tmp.path}/Library/Application Support/Google/Chrome/Default',
        )..createSync(recursive: true);
        File('${profile.parent.path}/Local State').writeAsStringSync(
          jsonEncode({
            'profile': {
              'info_cache': {
                'Default': {'name': 'Work'},
              },
            },
          }),
        );
        final db = sqlite3.open('${profile.path}/Cookies');
        db
          ..execute('CREATE TABLE meta (key TEXT, value TEXT)')
          ..execute("INSERT INTO meta VALUES ('version', '23')")
          ..execute(
            'CREATE TABLE cookies (host_key TEXT, name TEXT, value TEXT, '
            'encrypted_value BLOB, path TEXT, expires_utc INTEGER, '
            'is_secure INTEGER, is_httponly INTEGER, samesite INTEGER)',
          );
        db.execute('INSERT INTO cookies VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
          '.work.io',
          'sid',
          '',
          _chromiumEncrypt('pw', utf8.encode('abc')),
          '/',
          13400000000000000,
          1,
          1,
          1,
        ]);
        db.close();
        var asked = 0;
        final reader = ChromiumCookieReader(
          home: tmp.path,
          run: (cmd, args) async {
            asked++;
            return ProcessResult(0, 0, 'pw\n', '');
          },
        );

        final profiles = await reader.profiles(CookieBrowser.chrome);
        final cookies = await reader.read(
          CookieBrowser.chrome,
          profiles.single.path,
        );
        await reader.read(CookieBrowser.chrome, profiles.single.path);

        expect(profiles.single.name, 'Work');
        expect(cookies.single.value, 'abc');
        expect(cookies.single.httpOnly, isTrue);
        expect(cookies.single.sameSite, CookieSameSite.lax);
        expect(cookies.single.expires?.year, 2025);
        expect(asked, 1);
      },
      skip: !Platform.isMacOS,
    );

    test('a refused keychain is a KeychainDeniedException', () async {
      final profile = Directory(
        '${tmp.path}/Library/Application Support/Google/Chrome/Default',
      )..createSync(recursive: true);
      File('${profile.path}/Cookies').writeAsStringSync('');
      final reader = ChromiumCookieReader(
        home: tmp.path,
        run: (_, _) async => ProcessResult(0, 51, '', 'denied'),
      );

      expect(
        reader.read(CookieBrowser.chrome, profile.path),
        throwsA(isA<KeychainDeniedException>()),
      );
    });
  });

  group('Firefox', () {
    test('parses profiles.ini', () {
      final profiles = parseProfilesIni('''
[General]
StartWithLastProfile=1

[Profile0]
Name=default-release
IsRelative=1
Path=Profiles/abc.default-release

[Profile1]
Name=work
IsRelative=0
Path=/abs/work
''');
      expect(profiles, [
        (
          name: 'default-release',
          path: 'Profiles/abc.default-release',
          relative: true,
        ),
        (name: 'work', path: '/abs/work', relative: false),
      ]);
    });

    test('reads expiry in seconds or milliseconds', () {
      expect(firefoxExpiry(0), isNull);
      expect(firefoxExpiry(1800000000)?.year, 2027);
      expect(firefoxExpiry(1800000000000)?.year, 2027);
    });

    test('reads a profile', () async {
      File(
        '${tmp.path}/profiles.ini',
      ).writeAsStringSync('[Profile0]\nName=main\nIsRelative=1\nPath=p\n');
      Directory('${tmp.path}/p').createSync();
      final db = sqlite3.open('${tmp.path}/p/cookies.sqlite');
      db
        ..execute(
          'CREATE TABLE moz_cookies (name TEXT, value TEXT, host TEXT, '
          'path TEXT, expiry INTEGER, isSecure INTEGER, isHttpOnly INTEGER, '
          'sameSite INTEGER)',
        )
        ..execute(
          "INSERT INTO moz_cookies VALUES ('sid', 'abc', '.work.io', '/', "
          '1800000000, 1, 1, 2)',
        )
        ..close();
      final reader = FirefoxCookieReader(root: tmp.path);

      final profile = (await reader.profiles()).single;
      final cookie = (await reader.read(profile.path)).single;

      expect(profile.name, 'main');
      expect(cookie.domain, '.work.io');
      expect(cookie.value, 'abc');
      expect(cookie.sameSite, CookieSameSite.strict);
    });
  });

  group('parseBinaryCookies', () {
    Uint8List cookieRecord() {
      final strings = <int>[
        ...utf8.encode('.work.io'),
        0,
        ...utf8.encode('sid'),
        0,
        ...utf8.encode('/'),
        0,
        ...utf8.encode('abc'),
        0,
      ];
      const head = 56;
      final record = ByteData(head + strings.length);
      record.setUint32(0, head + strings.length, Endian.little);
      record.setUint32(8, 5, Endian.little); // secure + HttpOnly
      record.setUint32(16, head, Endian.little);
      record.setUint32(20, head + 9, Endian.little);
      record.setUint32(24, head + 13, Endian.little);
      record.setUint32(28, head + 15, Endian.little);
      record.setFloat64(40, 800000000, Endian.little);
      final bytes = record.buffer.asUint8List();
      bytes.setRange(head, bytes.length, strings);
      return bytes;
    }

    test('reads a page of cookies', () {
      final record = cookieRecord();
      final page = ByteData(12 + 4 + record.length);
      page.setUint32(0, 0x100);
      page.setUint32(4, 1, Endian.little);
      page.setUint32(8, 16, Endian.little);
      final pageBytes = page.buffer.asUint8List()
        ..setRange(16, 16 + record.length, record);
      final header = ByteData(12)
        ..setUint32(4, 1)
        ..setUint32(8, pageBytes.length);
      final file = header.buffer.asUint8List()
        ..setRange(0, 4, ascii.encode('cook'));

      final cookies = parseBinaryCookies(
        Uint8List.fromList([...file, ...pageBytes]),
      );

      expect(cookies.single.domain, '.work.io');
      expect(cookies.single.name, 'sid');
      expect(cookies.single.value, 'abc');
      expect(cookies.single.secure, isTrue);
      expect(cookies.single.httpOnly, isTrue);
      expect(cookies.single.expires?.year, 2026);
    });

    test('refuses another file', () {
      expect(
        () => parseBinaryCookies(Uint8List.fromList(utf8.encode('nope0000'))),
        throwsFormatException,
      );
    });
  });
}
