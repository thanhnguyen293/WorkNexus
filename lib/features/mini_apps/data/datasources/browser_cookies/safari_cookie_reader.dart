import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../domain/entities/browser_cookie.dart';
import 'join_path.dart';

/// Safari's cookies, kept in its own binary file inside its container. macOS
/// lets an app read it only with Full Disk Access: without it, reading throws
/// a [FileSystemException] for a refused permission.
class SafariCookieReader {
  const SafariCookieReader({this._home});

  final String? _home;

  String get _homeDir => _home ?? Platform.environment['HOME'] ?? '';

  /// Whether Safari is here at all. Its cookie file cannot be looked at
  /// without access, so this does not say whether it can be read.
  bool get installed =>
      Platform.isMacOS && Directory('/Applications/Safari.app').existsSync();

  List<String> get _candidates => [
    joinPath([
      _homeDir,
      'Library/Containers/com.apple.Safari/Data/Library/Cookies',
      'Cookies.binarycookies',
    ]),
    joinPath([_homeDir, 'Library/Cookies/Cookies.binarycookies']),
  ];

  Future<List<BrowserCookie>> read() async {
    FileSystemException? refused;
    for (final path in _candidates) {
      try {
        return parseBinaryCookies(await File(path).readAsBytes());
      } on FileSystemException catch (e) {
        refused ??= e;
      }
    }
    throw refused ?? const FileSystemException('No Safari cookies');
  }
}

/// Seconds between 1970 and 2001, where Apple's dates start.
const _appleEpoch = 978307200;

/// Reads a `Cookies.binarycookies` file: a big-endian page table, then pages
/// of little-endian cookie records whose strings sit at offsets inside them.
/// Throws a [FormatException] on a file that is not one.
List<BrowserCookie> parseBinaryCookies(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 8 || ascii.decode(bytes.sublist(0, 4)) != 'cook') {
    throw const FormatException('Not a binary cookies file');
  }
  final pages = data.getUint32(4);
  var pageStart = 8 + pages * 4;
  final cookies = <BrowserCookie>[];
  for (var i = 0; i < pages; i++) {
    final size = data.getUint32(8 + i * 4);
    final count = data.getUint32(pageStart + 4, Endian.little);
    for (var c = 0; c < count; c++) {
      final at =
          pageStart + data.getUint32(pageStart + 8 + c * 4, Endian.little);
      cookies.add(_cookieAt(bytes, data, at));
    }
    pageStart += size;
  }
  return cookies;
}

BrowserCookie _cookieAt(Uint8List bytes, ByteData data, int at) {
  int field(int offset) => data.getUint32(at + offset, Endian.little);
  String text(int offset) {
    final start = at + field(offset);
    var end = start;
    while (end < bytes.length && bytes[end] != 0) {
      end++;
    }
    return utf8.decode(bytes.sublist(start, end), allowMalformed: true);
  }

  final flags = field(8);
  final expiry = data.getFloat64(at + 40, Endian.little);
  return BrowserCookie(
    domain: text(16),
    name: text(20),
    path: text(24),
    value: text(28),
    expires: expiry <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            ((expiry + _appleEpoch) * 1000).round(),
            isUtc: true,
          ),
    secure: flags & 1 != 0,
    httpOnly: flags & 4 != 0,
  );
}
