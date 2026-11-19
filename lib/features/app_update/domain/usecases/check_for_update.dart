import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/available_update.dart';
import '../repositories/update_repository.dart';
import '../value_objects/app_version.dart';
import 'collect_release_notes.dart';

class CheckForUpdate {
  const CheckForUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<AvailableUpdate?>> call() async {
    final result = await _repository.fetchLatestStableRelease();
    if (result case Err(:final failure)) return Err(failure);
    final snapshot = result.valueOrNull;
    if (snapshot == null) return const Ok(null);

    final current = AppVersion.parse(snapshot.currentVersion);
    final latest = AppVersion.parse(snapshot.latestVersion);
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

    // The notes of every release since the running one, not only the
    // latest's: jumping from 1.0 to 1.9 shows what all of them brought. The
    // latest's own notes stay when the others cannot be read.
    final since = (await CollectReleaseNotes(_repository)(
      after: snapshot.currentVersion,
      upTo: snapshot.latestVersion,
    )).valueOrNull;

    return Ok(
      AvailableUpdate(
        currentVersion: snapshot.currentVersion,
        latestVersion: snapshot.latestVersion,
        releaseUrl: snapshot.releaseUrl,
        releaseNotes: since == null || since.isEmpty
            ? snapshot.releaseNotes
            : since,
        downloadUrl: snapshot.downloadUrl,
        sha256: snapshot.sha256,
      ),
    );
  }
}
