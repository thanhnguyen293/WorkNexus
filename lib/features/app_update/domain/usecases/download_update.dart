import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/app_release.dart';
import '../repositories/update_repository.dart';

/// Fetches [AppRelease]'s build and stages it for install. A release without
/// a checksum is refused: an unverified build never replaces the app.
class DownloadUpdate {
  const DownloadUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<String>> call(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    if (release.sha256 == null) {
      return Err(
        ParseFailure(
          'Release ${release.version} has no checksum for its build',
        ),
      );
    }
    return _repository.download(release, onProgress: onProgress);
  }
}
