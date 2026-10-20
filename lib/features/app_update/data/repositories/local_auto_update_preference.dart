import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/auto_update_preference.dart';
import '../datasources/auto_update_marker_file.dart';

/// The choice kept as [AutoUpdateMarkerFile]: present means off.
class LocalAutoUpdatePreference implements AutoUpdatePreference {
  LocalAutoUpdatePreference(this._marker);

  final AutoUpdateMarkerFile _marker;

  @override
  Future<Result<bool>> isEnabled() async {
    try {
      return Ok(!await _marker.exists());
    } on Exception catch (e) {
      return Err(
        StorageFailure('Could not read the automatic update choice', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setEnabled(bool enabled) async {
    try {
      await (enabled ? _marker.delete() : _marker.create());
      return const Ok(null);
    } on Exception catch (e) {
      return Err(
        StorageFailure('Could not save the automatic update choice', cause: e),
      );
    }
  }
}
