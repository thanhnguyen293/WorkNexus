import '../../../../core/error/result.dart';

/// What the mini apps' pages left in the shared web profile on this device:
/// cache, cookies (sign-ins) and site storage.
abstract interface class MiniAppBrowsingDataRepository {
  /// Whether this platform can clear it; when not, the calls below fail.
  bool get canClear;

  /// Clears the cache only: sign-ins stay, pages load afresh.
  Future<Result<void>> clearCache();

  /// Clears what the site at [url] keeps: its cookies, storage and cached
  /// files. Signs the user out of it.
  Future<Result<void>> clearSite(String url);

  /// Clears every site's cookies, storage and the cache. Signs the user out
  /// of every mini app.
  Future<Result<void>> clearAll(List<String> urls);
}
