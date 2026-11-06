import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

/// How Chromium on macOS and Linux encrypts a cookie's value: AES-128-CBC
/// under a key derived from a password it keeps in the system keychain, with
/// a fixed salt and IV. Values start with `v10` (or `v11` on Linux).
class ChromiumCookieCrypto {
  ChromiumCookieCrypto(this._key);

  /// The key Chromium derives from its keychain [password].
  factory ChromiumCookieCrypto.fromPassword(String password) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA1Digest(), 64))
      ..init(Pbkdf2Parameters(utf8.encode('saltysalt'), 1003, 16));
    return ChromiumCookieCrypto(derivator.process(utf8.encode(password)));
  }

  final Uint8List _key;

  static const _block = 16;

  /// The value Chromium wrote as [encrypted]. From database version 24 on it
  /// starts with the SHA-256 of the cookie's domain, which [hasDomainHash]
  /// drops. Null for a value it cannot decrypt (another scheme or key).
  String? decrypt(Uint8List encrypted, {required bool hasDomainHash}) {
    if (encrypted.length < 3 + _block) return null;
    final prefix = ascii.decode(encrypted.sublist(0, 3), allowInvalid: true);
    if (prefix != 'v10' && prefix != 'v11') return null;
    final body = encrypted.sublist(3);
    if (body.length % _block != 0) return null;
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        false,
        ParametersWithIV(
          KeyParameter(_key),
          Uint8List.fromList(List.filled(_block, 0x20)),
        ),
      );
    final plain = Uint8List(body.length);
    for (var at = 0; at < body.length; at += _block) {
      cipher.processBlock(body, at, plain, at);
    }
    final pad = plain.last;
    if (pad < 1 || pad > _block) return null;
    final end = plain.length - pad;
    final start = hasDomainHash ? 32 : 0;
    if (end < start) return null;
    return utf8.decode(plain.sublist(start, end), allowMalformed: true);
  }
}
