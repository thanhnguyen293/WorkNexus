import '../../../../core/error/result.dart';
import '../entities/panic_switch_config.dart';

/// Where this computer's panic switch settings are kept.
abstract interface class PanicSwitchConfigRepository {
  /// The saved settings, or the defaults when none were saved yet.
  Future<Result<PanicSwitchConfig>> load();

  Future<Result<void>> save(PanicSwitchConfig config);
}
