import 'package:freezed_annotation/freezed_annotation.dart';

part 'cookie_key.freezed.dart';

/// What tells one cookie from another: who it is for and its name. Kept,
/// without the value, to see later whether an imported cookie is still there.
@freezed
abstract class CookieKey with _$CookieKey {
  const factory CookieKey({
    /// The host it is sent to, without a leading dot.
    required String host,
    required String path,
    required String name,
  }) = _CookieKey;
}
