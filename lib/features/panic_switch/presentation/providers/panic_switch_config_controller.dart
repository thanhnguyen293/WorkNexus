import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/repositories/panic_switch_config_repository.dart';

/// This computer's panic switch settings, as Settings edits them.
class PanicSwitchConfigController extends AsyncNotifier<PanicSwitchConfig> {
  PanicSwitchConfigRepository get _repository =>
      getIt<PanicSwitchConfigRepository>();

  @override
  Future<PanicSwitchConfig> build() async => switch (await _repository.load()) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };

  /// Saves [change] applied to the current settings; when it cannot be saved
  /// nothing changes and the failure is returned for the UI to say so.
  Future<Result<void>> edit(
    PanicSwitchConfig Function(PanicSwitchConfig config) change,
  ) async {
    final current = state.asData?.value;
    if (current == null) return const Ok(null);
    final next = change(current);
    final saved = await _repository.save(next);
    if (saved.isOk) state = AsyncData(next);
    return saved;
  }
}

final panicSwitchConfigProvider =
    AsyncNotifierProvider<PanicSwitchConfigController, PanicSwitchConfig>(
      PanicSwitchConfigController.new,
    );
