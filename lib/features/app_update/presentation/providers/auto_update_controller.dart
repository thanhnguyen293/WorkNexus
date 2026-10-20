import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/auto_update_preference.dart';
import 'update_controller.dart';

/// Whether the app updates itself in the background (the settings switch).
/// Turning it on looks for an update at once; turning it off stops the hourly
/// checks, so nothing new is downloaded until the user asks.
class AutoUpdateController extends AsyncNotifier<bool> {
  AutoUpdatePreference get _preference => getIt<AutoUpdatePreference>();

  @override
  Future<bool> build() async => switch (await _preference.isEnabled()) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };

  /// Saves the choice; when it cannot be saved nothing changes and the
  /// failure is returned for the UI to say so.
  Future<Result<void>> set(bool enabled) async {
    final saved = await _preference.setEnabled(enabled);
    if (saved.isErr) return saved;
    state = AsyncData(enabled);
    if (enabled) {
      unawaited(
        ref.read(updateControllerProvider.notifier).checkInBackground(),
      );
    }
    return saved;
  }
}

final autoUpdateProvider = AsyncNotifierProvider<AutoUpdateController, bool>(
  AutoUpdateController.new,
);
