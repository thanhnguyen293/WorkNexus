import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Auth key xxd expects for a password (non-LDAP) login: md5 hex of the
/// password. Sent in both `sysgetserverinfo` and `userLogin`.
String xxdPasswordAuthKey(String password) => _md5(password);

/// `sid` query parameter that signs a `fileDownload` URL:
/// md5(sessionID + fileName), where sessionID comes from the `syssessionid`
/// packet pushed after login.
String xxdFileSid(String sessionId, String fileName) =>
    _md5('$sessionId$fileName');

String _md5(String input) => md5.convert(utf8.encode(input)).toString();

/// The key `im-authorize` checks, derived from the server info's
/// [authToken] as the official client's `authKeyForServer` does: a 64-char
/// token is hashed with the account and the current [window]-second slot of
/// the server's clock ([serverNow]); a shorter one is cut to 32 chars. The
/// key is that value followed by its own md5.
String xxdAuthorizeKey({
  required String account,
  required String authToken,
  required DateTime serverNow,
  int window = 20,
}) {
  final slot = (serverNow.millisecondsSinceEpoch / 1000 / window).round();
  final base = authToken.length == 64
      ? _md5('$account$authToken$slot')
      : (authToken.length >= 32 ? authToken.substring(0, 32) : authToken);
  return '$base${_md5(base)}';
}
