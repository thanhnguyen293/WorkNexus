import '../../../../core/error/result.dart';
import '../entities/app_release.dart';

/// Where new builds come from and how they replace the running app.
abstract interface class UpdateRepository {
  /// The latest stable release with a build for this platform; null when
  /// there is none.
  Future<Result<AppRelease?>> latestRelease();

  /// Downloads and verifies [release], unpacks it, and returns the folder
  /// holding the new build, ready for [install].
  Future<Result<String>> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  });

  /// Hands [stagedPath] to a helper that swaps it in once this process has
  /// exited and starts the new build, then quits the app. Only returns when
  /// that could not be started.
  Future<Result<void>> install(String stagedPath);
}
