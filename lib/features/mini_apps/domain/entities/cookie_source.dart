import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/cookie_browser.dart';

part 'cookie_source.freezed.dart';

/// One browser profile whose cookies can be read: [profileId] is how the
/// data layer finds it again, [profileName] what the user calls it.
@freezed
abstract class CookieSource with _$CookieSource {
  const factory CookieSource({
    required CookieBrowser browser,
    required String profileId,
    required String profileName,
  }) = _CookieSource;
}
