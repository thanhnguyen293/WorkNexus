import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_cipher.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_signing.dart';

void main() {
  // Vectors produced with Node's crypto.createCipheriv (tool/xxd_fixtures.mjs),
  // the same call the xuanxuan client uses.
  final fixture = jsonDecode(
    File('test/fixtures/xxd/cipher_cases.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final cipher = XxdCipher(fixture['token']! as String);

  group('XxdCipher', () {
    for (final c in (fixture['cases']! as List).cast<Map<String, Object?>>()) {
      final plain = c['plain']! as String;
      final expected = c['cipherBase64']! as String;

      test('matches Node for ${jsonEncode(plain)}', () {
        expect(base64Encode(cipher.encrypt(plain)), expected);
        expect(cipher.decrypt(base64Decode(expected)), plain);
      });
    }

    test('rejects a token that is not 32 bytes', () {
      expect(() => XxdCipher('short'), throwsArgumentError);
    });

    test('rejects ciphertext that is not whole blocks', () {
      expect(
        () => cipher.decrypt(utf8.encode('not encrypted')),
        throwsFormatException,
      );
      expect(() => cipher.decrypt(const []), throwsFormatException);
    });

    test('fails on ciphertext from another key', () {
      final other = XxdCipher('fedcba9876543210fedcba9876543210');
      expect(
        () => other.decrypt(cipher.encrypt('hello xxd')),
        throwsA(anything),
      );
    });
  });

  group('xxd signing', () {
    test('password auth key is md5 hex', () {
      expect(xxdPasswordAuthKey('123456'), 'e10adc3949ba59abbe56e057f20f883e');
    });

    test('file sid is md5(sessionID + fileName)', () {
      expect(
        xxdFileSid('c8d0sessionid', 'image.png'),
        '3dbb5fa00a3f7f779b18992a98309077',
      );
    });
  });
}
