import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/entities/browser_cookie.dart';
import '../../domain/value_objects/cookie_key.dart';
import '../../domain/value_objects/cookie_same_site.dart';

/// The cookies of the web profile the mini apps' web views share, through
/// the web view's own cookie store. Linux's web view is another one, with no
/// way to set a cookie's HttpOnly flag or expiry, so it is left out.
class WebViewCookieDatasource {
  const WebViewCookieDatasource();

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  CookieManager get _manager => CookieManager.instance();

  /// Sets [cookie]; false when the web view refused it.
  Future<bool> write(BrowserCookie cookie) => _manager.setCookie(
    url: _url(cookie.host, cookie.path, secure: cookie.secure),
    name: cookie.name,
    value: cookie.value,
    path: cookie.path,
    // A host-only cookie takes its host from the address alone.
    domain: cookie.includesSubdomains ? cookie.domain : null,
    expiresDate: cookie.expires?.millisecondsSinceEpoch,
    isSecure: cookie.secure,
    isHttpOnly: cookie.httpOnly,
    sameSite: switch (cookie.sameSite) {
      CookieSameSite.none => HTTPCookieSameSitePolicy.NONE,
      CookieSameSite.lax => HTTPCookieSameSitePolicy.LAX,
      CookieSameSite.strict => HTTPCookieSameSitePolicy.STRICT,
      CookieSameSite.unspecified => null,
    },
  );

  /// The names of the live cookies the web view would send to [host]'s
  /// [path].
  Future<Set<String>> namesAt(String host, String path) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cookies = await _manager.getCookies(
      url: _url(host, path, secure: true),
    );
    return {
      for (final c in cookies)
        if (c.expiresDate == null || c.expiresDate! > now) c.name,
    };
  }

  /// Which of [keys] are there, asking once per address.
  Future<Set<CookieKey>> present(List<CookieKey> keys) async {
    final found = <CookieKey>{};
    final byAddress = <(String, String), List<CookieKey>>{};
    for (final key in keys) {
      (byAddress[(key.host, key.path)] ??= []).add(key);
    }
    for (final MapEntry(key: (host, path), :value) in byAddress.entries) {
      final names = await namesAt(host, path);
      found.addAll(value.where((k) => names.contains(k.name)));
    }
    return found;
  }

  static WebUri _url(String host, String path, {required bool secure}) =>
      WebUri('${secure ? 'https' : 'http'}://$host$path');
}
