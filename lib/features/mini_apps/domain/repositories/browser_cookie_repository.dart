import '../../../../core/error/result.dart';
import '../entities/browser_cookie.dart';
import '../entities/cookie_source.dart';

/// The cookies the browsers on this device keep.
abstract interface class BrowserCookieRepository {
  /// The browser profiles found here whose cookies can be read.
  Future<Result<List<CookieSource>>> sources();

  /// Every cookie [source] keeps. An [AuthFailure] means the system refused
  /// access (Safari's needs Full Disk Access; Chromium's key asks the
  /// keychain).
  Future<Result<List<BrowserCookie>>> read(CookieSource source);
}
