import 'package:freezed_annotation/freezed_annotation.dart';

part 'opencode_credential.freezed.dart';

/// How a provider is authenticated inside OpenCode's own credential store.
enum OpenCodeAuthType {
  /// A user-supplied API key — the only kind WorkNexus can set or replace.
  api,

  /// A browser/device OAuth login, only `opencode auth login` can refresh it.
  oauth,

  /// A provider-issued "well-known" token.
  wellKnown,

  /// Anything a newer OpenCode writes that we don't model yet.
  unknown,
}

/// One provider entry from OpenCode's credential store.
///
/// The secret itself never leaves the data layer: only [keyPreview] — a masked
/// tail such as `••••••a1b2` — travels to domain and presentation, so an API key
/// can be recognized without being exposed. Null for non-[OpenCodeAuthType.api]
/// entries.
@freezed
abstract class OpenCodeCredential with _$OpenCodeCredential {
  const factory OpenCodeCredential({
    required String providerId,
    required OpenCodeAuthType type,
    String? keyPreview,
  }) = _OpenCodeCredential;
}
