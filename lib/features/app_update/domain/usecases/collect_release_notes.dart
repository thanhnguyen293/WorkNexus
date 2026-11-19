import '../../../../core/error/result.dart';
import '../repositories/update_repository.dart';
import '../value_objects/app_version.dart';

/// The notes of every stable release after [after] up to and including
/// [upTo], newest first, as one Markdown text with a heading per version.
/// Empty when none of them has notes.
class CollectReleaseNotes {
  const CollectReleaseNotes(this._repository);

  final UpdateRepository _repository;

  Future<Result<String>> call({
    required String after,
    required String upTo,
  }) async => switch (await _repository.fetchStableReleaseNotes()) {
    Ok(:final value) => Ok(combine(value, after: after, upTo: upTo)),
    Err(:final failure) => Err(failure),
  };

  static String combine(
    List<ReleaseNote> releases, {
    required String after,
    required String upTo,
  }) {
    final from = AppVersion.parse(after);
    final to = AppVersion.parse(upTo);
    if (from == null || to == null) return '';
    final picked = [
      for (final r in releases)
        if (AppVersion.parse(r.version) case final v?
            when !v.isPrerelease &&
                v.compareTo(from) > 0 &&
                v.compareTo(to) <= 0 &&
                r.notes.trim().isNotEmpty)
          (version: v, release: r),
    ]..sort((a, b) => b.version.compareTo(a.version));
    return [
      for (final p in picked)
        '## ${_tagged(p.release.version)}\n\n${p.release.notes.trim()}',
    ].join('\n\n');
  }

  static String _tagged(String version) =>
      version.startsWith('v') ? version : 'v$version';
}
