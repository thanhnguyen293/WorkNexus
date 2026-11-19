import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/panic_switch_config.dart';
import '../repositories/app_switcher.dart';

/// Does what the switch is set to: brings the target app forward, hides the
/// chosen apps, then WorkNexus itself. Each step runs even when an earlier
/// one fails — a half-done switch beats none; the first failure is returned.
class RunPanicSwitch {
  const RunPanicSwitch(this._apps);

  final AppSwitcher _apps;

  Future<Result<void>> call(PanicSwitchConfig config) async {
    Failure? first;
    void keep(Result<void> result) => first ??= result.failureOrNull;

    final target = config.targetApp;
    if (target != null) keep(await _apps.activate(target));
    for (final app in config.appsToHide) {
      if (app.id == target?.id) continue;
      keep(await _apps.hide(app));
    }
    if (config.hideSelf) keep(await _apps.hideSelf());

    final failure = first;
    return failure == null ? const Ok(null) : Err(failure);
  }
}
