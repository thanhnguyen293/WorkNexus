import '../../../../core/error/result.dart';
import '../entities/app_release.dart';
import '../repositories/update_repository.dart';
import '../value_objects/app_version.dart';

/// The latest stable release when it is newer than [current]; null when the
/// app is up to date or [current] is not a release build (local and nightly
/// builds never update themselves).
class CheckForUpdate {
  const CheckForUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<AppRelease?>> call(String current) async {
    final installed = AppVersion.tryParse(current);
    if (installed == null) return const Ok(null);
    final result = await _repository.latestRelease();
    return switch (result) {
      Ok(:final value) => Ok(
        value != null && value.version > installed ? value : null,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
