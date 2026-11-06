import 'package:freezed_annotation/freezed_annotation.dart';

import 'browser_cookie.dart';

part 'cookie_site.freezed.dart';

/// A site's cookies in one browser profile, offered as one choice.
@freezed
abstract class CookieSite with _$CookieSite {
  const factory CookieSite({
    /// Its name, e.g. `google.com`.
    required String site,
    required List<BrowserCookie> cookies,

    /// Whether a mini app opens this site, so it is offered first.
    @Default(false) bool usedByMiniApp,
  }) = _CookieSite;
}
