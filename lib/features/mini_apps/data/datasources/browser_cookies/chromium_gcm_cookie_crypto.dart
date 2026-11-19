import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import 'chromium_cookie_crypto.dart';

/// How Chromium on Windows encrypts a cookie's value: AES-256-GCM under a key
/// kept DPAPI-protected in `Local State`. Values start with `v10`, then a
/// 12-byte nonce, the ciphertext and a 16-byte tag. `v20` values use Chrome's
/// app-bound key instead, which no other app can get, and decrypt to null.
class ChromiumGcmCookieCrypto implements CookieDecrypter {
  const ChromiumGcmCookieCrypto(this._key);

  final Uint8List _key;

  static const _nonce = 12;
  static const _tag = 16;

  @override
  String? decrypt(Uint8List encrypted, {required bool hasDomainHash}) {
    if (encrypted.length < 3 + _nonce + _tag) return null;
    final prefix = ascii.decode(encrypted.sublist(0, 3), allowInvalid: true);
    if (prefix != 'v10' && prefix != 'v11') return null;
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key),
          _tag * 8,
          encrypted.sublist(3, 3 + _nonce),
          Uint8List(0),
        ),
      );
    final Uint8List plain;
    try {
      plain = cipher.process(encrypted.sublist(3 + _nonce));
    } on InvalidCipherTextException {
      return null;
    } on ArgumentError {
      return null;
    }
    final start = hasDomainHash ? 32 : 0;
    if (plain.length < start) return null;
    return utf8.decode(plain.sublist(start), allowMalformed: true);
  }
}
