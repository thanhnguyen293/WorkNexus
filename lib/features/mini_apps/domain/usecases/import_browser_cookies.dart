import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/browser_cookie.dart';
import '../entities/cookie_import.dart';
import '../entities/cookie_source.dart';
import '../repositories/browser_cookie_repository.dart';
import '../repositories/cookie_import_repository.dart';
import '../repositories/web_view_cookie_repository.dart';
import '../value_objects/cookie_key.dart';
import '../value_objects/cookie_site_of.dart';

/// Brings the cookies of the chosen [sites] from a browser profile into the
/// mini apps' web view, and remembers where they came from so they can be
/// imported again once they run out. Answers how many cookies went in.
///
/// It reads the profile afresh rather than taking cookies already shown, so
/// importing again picks up the sign-in the browser has now.
class ImportBrowserCookies {
  const ImportBrowserCookies(
    this._browsers,
    this._webView,
    this._imports, {
    this._now = DateTime.now,
  });

  final BrowserCookieRepository _browsers;
  final WebViewCookieRepository _webView;
  final CookieImportRepository _imports;
  final DateTime Function() _now;

  Future<Result<int>> call(CookieSource source, Set<String> sites) async {
    final now = _now();
    final List<BrowserCookie> cookies;
    switch (await _browsers.read(source)) {
      case Ok(:final value):
        cookies = value;
      case Err(:final failure):
        return Err(failure);
    }
    final chosen = [
      for (final c in cookies)
        if (c.value.isNotEmpty &&
            !c.isExpiredAt(now) &&
            sites.contains(cookieSiteOf(c.domain)))
          c,
    ];
    if (chosen.isEmpty) {
      return const Err(NotFoundFailure('The browser has no such cookies'));
    }
    if (await _webView.write(chosen) case Err(:final failure)) {
      return Err(failure);
    }
    final bySite = <String, List<BrowserCookie>>{};
    for (final c in chosen) {
      (bySite[cookieSiteOf(c.domain)] ??= []).add(c);
    }
    final saved = await _imports.save([
      for (final MapEntry(:key, :value) in bySite.entries)
        CookieImport(
          site: key,
          source: source,
          importedAt: now,
          keys: _signInKeys(value),
        ),
    ]);
    return saved.fold((_) => Ok(chosen.length), Err<int>.new);
  }

  /// The cookies a sign-in rests on. Sites keep their session in HttpOnly
  /// cookies, while the rest are mostly short-lived analytics that come and
  /// go; watching those would call a live sign-in expired. A site with no
  /// HttpOnly cookie is watched whole.
  static List<CookieKey> _signInKeys(List<BrowserCookie> cookies) {
    final httpOnly = cookies.where((c) => c.httpOnly).toList();
    return {
      for (final c in httpOnly.isEmpty ? cookies : httpOnly) c.key,
    }.toList();
  }
}
