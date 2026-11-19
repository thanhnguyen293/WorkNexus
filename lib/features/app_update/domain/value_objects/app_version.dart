/// A release version (`1.4.1`, `v1.5.0-beta.1`), ordered as semver orders
/// them: a pre-release sorts before its release.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, this.prerelease);

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;

  bool get isPrerelease => prerelease != null;

  static final _pattern = RegExp(
    r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static AppVersion? parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final major = int.tryParse(match[1]!);
    final minor = int.tryParse(match[2]!);
    final patch = int.tryParse(match[3]!);
    if (major == null || minor == null || patch == null) return null;
    return AppVersion(major, minor, patch, match[4]);
  }

  @override
  int compareTo(AppVersion other) {
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
