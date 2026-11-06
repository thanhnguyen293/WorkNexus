import '../../../../core/error/result.dart';
import '../entities/browser_cookie.dart';
import '../value_objects/cookie_key.dart';

/// The cookies of the web profile the mini apps share.
abstract interface class WebViewCookieRepository {
  /// Whether this platform's web view takes cookies from outside.
  bool get canWrite;

  /// Sets [cookies], replacing any with the same name, host and path.
  Future<Result<void>> write(List<BrowserCookie> cookies);

  /// Which of [keys] the web view still has.
  Future<Result<Set<CookieKey>>> present(List<CookieKey> keys);
}
