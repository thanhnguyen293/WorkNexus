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
