import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/available_update.dart';
import '../repositories/update_repository.dart';

class CheckForUpdate {
  const CheckForUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<AvailableUpdate?>> call() async {
    final result = await _repository.fetchLatestStableRelease();
    return result.fold((snapshot) {
      if (snapshot == null) return const Ok(null);

      final current = _Version.parse(snapshot.currentVersion);
      final latest = _Version.parse(snapshot.latestVersion);
      if (current == null || latest == null) {
        return const Err(
          ParseFailure('GitHub returned an invalid stable release version'),
        );
      }
      // The datasource already rejects `prerelease: true` from the API.
      // If the tag name still carries a pre-release suffix (e.g. the maintainer
      // tagged `v1.1.0-alpha.1` but set `prerelease: false` on GitHub), treat
      // it as "no stable update available" rather than a hard error.
      if (latest.isPrerelease) return const Ok(null);
      if (latest.compareTo(current) <= 0) return const Ok(null);

      return Ok(
        AvailableUpdate(
          currentVersion: snapshot.currentVersion,
          latestVersion: snapshot.latestVersion,
          releaseUrl: snapshot.releaseUrl,
          downloadUrl: snapshot.downloadUrl,
          sha256: snapshot.sha256,
        ),
      );
    }, Err<AvailableUpdate?>.new);
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.prerelease);

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;

  bool get isPrerelease => prerelease != null;

  static final _pattern = RegExp(
    r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static _Version? parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final major = int.tryParse(match[1]!);
    final minor = int.tryParse(match[2]!);
    final patch = int.tryParse(match[3]!);
    if (major == null || minor == null || patch == null) return null;
    return _Version(major, minor, patch, match[4]);
  }

  @override
  int compareTo(_Version other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;
    final patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) return patchComparison;
    if (prerelease == null) return other.prerelease == null ? 0 : 1;
    if (other.prerelease == null) return -1;
    return prerelease!.compareTo(other.prerelease!);
  }
}
