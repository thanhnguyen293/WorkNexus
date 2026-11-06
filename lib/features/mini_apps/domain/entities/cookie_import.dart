import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/cookie_key.dart';
import 'cookie_source.dart';

part 'cookie_import.freezed.dart';

/// That a [site]'s cookies were brought in from [source]: kept, without the
/// cookies themselves, to import them again from the same place and to see
/// whether they are still there. One per site; the latest import wins.
@freezed
abstract class CookieImport with _$CookieImport {
  const factory CookieImport({
    required String site,
    required CookieSource source,
    required DateTime importedAt,

    /// The cookies whose loss means the sign-in is gone.
    required List<CookieKey> keys,
  }) = _CookieImport;
}

/// An import and whether its sign-in cookies are still in the web view.
@freezed
abstract class CookieImportState with _$CookieImportState {
  const CookieImportState._();

  const factory CookieImportState({
    required CookieImport import,

    /// How many of [CookieImport.keys] are gone (expired or removed).
    @Default(0) int missing,
  }) = _CookieImportState;

  bool get expired => missing > 0;
}
