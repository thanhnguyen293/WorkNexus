import '../entities/browser_cookie.dart';
import '../entities/cookie_site.dart';
import '../value_objects/cookie_site_of.dart';

/// Groups a browser profile's cookies into the sites a user picks from: the
/// ones a mini app opens first, then by name. Expired and empty cookies are
/// left out, as a web view would not take them.
class GroupCookiesBySite {
  const GroupCookiesBySite();

  List<CookieSite> call(
    List<BrowserCookie> cookies, {
    required Iterable<String> miniAppUrls,
    required DateTime now,
  }) {
    final appSites = {
      for (final url in miniAppUrls)
        if (Uri.tryParse(url)?.host case final host? when host.isNotEmpty)
          cookieSiteOf(host),
    };
    final bySite = <String, List<BrowserCookie>>{};
    for (final cookie in cookies) {
      if (cookie.value.isEmpty || cookie.isExpiredAt(now)) continue;
      (bySite[cookieSiteOf(cookie.domain)] ??= []).add(cookie);
    }
    final sites = [
      for (final MapEntry(:key, :value) in bySite.entries)
        CookieSite(
          site: key,
          cookies: value,
          usedByMiniApp: appSites.contains(key),
        ),
    ];
    return sites..sort((a, b) {
      if (a.usedByMiniApp != b.usedByMiniApp) return a.usedByMiniApp ? -1 : 1;
      return a.site.compareTo(b.site);
    });
  }
}
