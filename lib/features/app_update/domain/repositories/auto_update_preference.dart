import '../../../../core/error/result.dart';

/// Whether the app looks for new versions, and downloads them, on its own. Off,
/// it only does so when the user asks ("Check for updates"). On by default.
abstract class AutoUpdatePreference {
  Future<Result<bool>> isEnabled();

  Future<Result<void>> setEnabled(bool enabled);
}
