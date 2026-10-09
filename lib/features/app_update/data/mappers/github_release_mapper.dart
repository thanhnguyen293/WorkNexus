import '../../domain/entities/app_release.dart';
import '../../domain/value_objects/app_version.dart';
import '../models/github_release_dto.dart';

/// Name of the checksum file CI attaches next to the build zips
/// (`sha256sum` output: `<hex>  <file name>` per line).
const checksumAssetName = 'SHA256SUMS.txt';

/// [dto] as a release offering [assetName]; null when its tag is not a
/// version or it has no build for this platform.
AppRelease? releaseFromDto(
  GithubReleaseDto dto, {
  required String assetName,
  String? checksums,
}) {
  final version = AppVersion.tryParse(dto.tagName);
  final url = dto.assets[assetName];
  if (version == null || url == null) return null;
  return AppRelease(
    version: version,
    notes: dto.body,
    pageUrl: dto.htmlUrl,
    downloadUrl: url,
    sha256: checksums == null ? null : checksumFor(checksums, assetName),
  );
}

/// The hash listed for [fileName] in a `sha256sum`-style [checksums] file.
String? checksumFor(String checksums, String fileName) {
  for (final line in checksums.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    // sha256sum marks binary mode with a leading `*` on the name.
    if (parts.length == 2 &&
        parts[1].replaceFirst('*', '') == fileName &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(parts[0])) {
      return parts[0].toLowerCase();
    }
  }
  return null;
}
