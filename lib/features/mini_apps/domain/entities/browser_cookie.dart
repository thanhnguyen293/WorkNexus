import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/cookie_key.dart';
import '../value_objects/cookie_same_site.dart';

part 'browser_cookie.freezed.dart';

/// A cookie as a browser keeps it. [domain] keeps its leading dot when the
/// cookie goes to subdomains too, as browsers write it.
@freezed
abstract class BrowserCookie with _$BrowserCookie {
  const BrowserCookie._();

  const factory BrowserCookie({
    required String name,
    required String value,
    required String domain,
    @Default('/') String path,

    /// When it expires; null for one that lasts the session.
    DateTime? expires,
    @Default(false) bool secure,
    @Default(false) bool httpOnly,
    @Default(CookieSameSite.unspecified) CookieSameSite sameSite,
  }) = _BrowserCookie;

  /// The host it is sent to, without the leading dot.
  String get host => domain.startsWith('.') ? domain.substring(1) : domain;

  /// Whether it goes to subdomains of [host] too.
  bool get includesSubdomains => domain.startsWith('.');

  CookieKey get key => CookieKey(host: host, path: path, name: name);

  bool isExpiredAt(DateTime now) => expires?.isBefore(now) ?? false;
}
