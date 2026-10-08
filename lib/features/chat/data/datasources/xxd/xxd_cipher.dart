import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

/// AES-256-CBC (PKCS7) for xxd socket frames, used when `serverInfo` returns
/// `enableClientAES`. Key = the 32-char session token, IV = its first 16 chars
/// (both as UTF-8 bytes, as Node's `createCipheriv` does with string keys).
///
/// Padding is done here rather than with pointycastle's `PaddedBlockCipher`,
/// which crashes on empty input and accepts ciphertext whose length is not a
/// whole number of blocks.
final class XxdCipher {
  XxdCipher(String token)
    : _key = Uint8List.fromList(utf8.encode(token)),
      _iv = Uint8List.fromList(utf8.encode(token).take(_block).toList()) {
    if (_key.length != 32) {
      throw ArgumentError.value(
        token,
        'token',
        'must be 32 bytes for AES-256 (got ${_key.length})',
      );
    }
  }

  static const _block = 16;

  final Uint8List _key;
  final Uint8List _iv;

  Uint8List encrypt(String plainText) {
    final data = utf8.encode(plainText);
    final pad = _block - data.length % _block;
    final padded = Uint8List(data.length + pad)
      ..setAll(0, data)
      ..fillRange(data.length, data.length + pad, pad);
    return _run(padded, forEncryption: true);
  }

  /// Throws [FormatException] when [cipherText] is not valid for this key.
  String decrypt(List<int> cipherText) {
    if (cipherText.isEmpty || cipherText.length % _block != 0) {
      throw FormatException(
        'Ciphertext length ${cipherText.length} is not a multiple of $_block',
      );
    }
    final plain = _run(Uint8List.fromList(cipherText), forEncryption: false);
    final pad = plain.last;
    if (pad < 1 ||
        pad > _block ||
        plain.sublist(plain.length - pad).any((b) => b != pad)) {
      throw const FormatException('Bad PKCS7 padding (wrong key?)');
    }
    return utf8.decode(plain.sublist(0, plain.length - pad));
  }

  Uint8List _run(Uint8List input, {required bool forEncryption}) {
    final cbc = CBCBlockCipher(AESEngine())
      ..init(forEncryption, ParametersWithIV(KeyParameter(_key), _iv));
    final out = Uint8List(input.length);
    for (var offset = 0; offset < input.length; offset += _block) {
      cbc.processBlock(input, offset, out, offset);
    }
    return out;
  }
}
