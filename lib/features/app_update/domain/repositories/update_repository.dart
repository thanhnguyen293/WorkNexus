import '../../../../core/error/result.dart';
import '../entities/available_update.dart';

typedef UpdateVersionSnapshot = ({
  String currentVersion,
  String latestVersion,
  String releaseUrl,
  String releaseNotes,
  String? downloadUrl,
  String? sha256,
});

abstract class UpdateRepository {
  /// The version of the running build (`1.4.1`).
  Future<String> currentVersion();

  Future<Result<UpdateVersionSnapshot?>> fetchLatestStableRelease();

  /// Downloads [update], verifies its checksum and unpacks it; returns the
  /// path of the staged build.
  Future<Result<String>> download(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  });

  /// Swaps the staged build in for the running one and restarts the app.
  /// Only returns when the install could not start.
  Future<Result<void>> install(String stagedPath);
}
