import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/panic_switch_config.dart';
import '../repositories/app_switcher.dart';

/// Does what the switch is set to: hides every app but the ones to open,
/// opens those (the first ends up in front), then hides WorkNexus itself.
/// Each step runs even when an earlier one fails — a half-done switch beats
/// none; the first failure is returned.
class RunPanicSwitch {
  const RunPanicSwitch(this._apps);

  final AppSwitcher _apps;

  Future<Result<void>> call(PanicSwitchConfig config) async {
    Failure? first;
    void keep(Result<void> result) => first ??= result.failureOrNull;

    keep(await _apps.hideOthers(config.appsToOpen));
    // The last one opened is in front, so open the first last.
    for (final app in config.appsToOpen.reversed) {
      keep(await _apps.activate(app));
    }
    // WorkNexus is never one of the apps to open, so it hides too.
    keep(await _apps.hideSelf());

    final failure = first;
    return failure == null ? const Ok(null) : Err(failure);
  }
}
