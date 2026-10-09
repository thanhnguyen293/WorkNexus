/// A stable release newer than the running build.
///
/// [downloadUrl] and [sha256] are null when the release carries no build (or
/// no checksum) for this platform; the update then can only be fetched by hand
/// from [releaseUrl].
class AvailableUpdate {
  const AvailableUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.downloadUrl,
    this.sha256,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? downloadUrl;
  final String? sha256;

  bool get canInstallInApp => downloadUrl != null && sha256 != null;
}
