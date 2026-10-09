import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/app_version.dart';

part 'app_release.freezed.dart';

/// A published stable release with a build for the running platform.
@freezed
abstract class AppRelease with _$AppRelease {
  const factory AppRelease({
    required AppVersion version,

    /// Release notes (Markdown, the generated changelog).
    required String notes,

    /// The release page, for installing by hand when the in-app install
    /// cannot (e.g. the app sits in a folder the user cannot write to).
    required String pageUrl,

    /// The zipped build for this platform.
    required String downloadUrl,

    /// Expected SHA-256 of the zip (lower-case hex); null when the release
    /// carries no checksum file, and the download is then refused.
    String? sha256,
  }) = _AppRelease;
}
