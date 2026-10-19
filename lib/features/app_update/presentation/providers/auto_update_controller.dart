import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../domain/repositories/auto_update_preference.dart';
import 'update_controller.dart';

/// Whether the app updates itself in the background (the settings switch).
/// Turning it on looks for an update at once; turning it off stops the hourly
/// checks, so nothing new is downloaded until the user asks.
class AutoUpdateController extends AsyncNotifier<bool> {
  AutoUpdatePreference get _preference => getIt<AutoUpdatePreference>();

  @override
  Future<bool> build() => _preference.isEnabled();

  Future<void> set(bool enabled) async {
    await _preference.setEnabled(enabled);
    state = AsyncData(enabled);
    if (enabled) {
      unawaited(
        ref.read(updateControllerProvider.notifier).checkInBackground(),
      );
    }
  }
}

final autoUpdateProvider = AsyncNotifierProvider<AutoUpdateController, bool>(
  AutoUpdateController.new,
);
