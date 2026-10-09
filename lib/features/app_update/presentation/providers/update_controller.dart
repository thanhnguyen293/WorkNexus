import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/available_update.dart';
import '../../domain/usecases/check_for_update.dart';
import '../../domain/usecases/download_update.dart';
import '../../domain/usecases/install_update.dart';
import 'update_state.dart';

/// Keeps the app current in the background: looks for a newer stable release
/// when created and every [checkEvery], downloads and verifies it on its own,
/// then holds it in [UpdateReady] until the user asks to restart into it.
class UpdateController extends Notifier<UpdateState> {
  UpdateController({
    required CheckForUpdate checkForUpdate,
    required DownloadUpdate downloadUpdate,
    required InstallUpdate installUpdate,
    this.checkEvery = const Duration(hours: 1),
  }) : _checkForUpdate = checkForUpdate,
       _downloadUpdate = downloadUpdate,
       _installUpdate = installUpdate;

  final CheckForUpdate _checkForUpdate;
  final DownloadUpdate _downloadUpdate;
  final InstallUpdate _installUpdate;
  final Duration checkEvery;

  Future<Result<AvailableUpdate?>>? _inFlight;

  @override
  UpdateState build() {
    final timer = Timer.periodic(checkEvery, (_) => check());
    ref.onDispose(timer.cancel);
    // The first check follows right behind; state must not change in build.
    scheduleMicrotask(check);
    return const UpdateIdle();
  }

  /// Looks for a newer stable release and, when it has a build for this
  /// platform, starts downloading it. Returns what was found so a manual
  /// check can tell the user; a check already running is shared, not repeated.
  Future<Result<AvailableUpdate?>> check() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<Result<AvailableUpdate?>> _run() async {
    final result = await _checkForUpdate();
    switch (result) {
      case Ok(value: final update?):
        _stage(update);
      case Ok():
        break;
      case Err(:final failure):
        // A background check has no UI to tell; the manual one toasts it.
        appTalker.warning('Update check failed: ${failure.message}');
    }
    return result;
  }

  /// Moves [update] towards [UpdateReady] unless it is already on its way. A
  /// failed attempt is retried by the next check.
  void _stage(AvailableUpdate update) {
    final current = state;
    if (current is UpdateDownloading || current is UpdateInstalling) return;
    if (current is UpdateReady &&
        current.update.latestVersion == update.latestVersion) {
      return;
    }
    if (!update.canInstallInApp) {
      state = UpdateManual(update);
      return;
    }
    unawaited(_download(update));
  }

  Future<void> _download(AvailableUpdate update) async {
    state = UpdateDownloading(update, 0);
    var shown = 0.0;
    try {
      final downloaded = await _downloadUpdate(
        update,
        onProgress: (progress) {
          // Whole percents only: dio reports every chunk.
          if (progress - shown < 0.01) return;
          shown = progress;
          state = UpdateDownloading(update, progress);
        },
      );
      state = switch (downloaded) {
        Ok(:final value) => UpdateReady(update, value),
        Err(:final failure) => _failed(update, failure.message, failure.cause),
      };
    } catch (error) {
      // Whatever the repository did not map must still leave the busy state.
      state = _failed(update, 'Downloading the update failed', error);
    }
  }

  /// Only returns when the update could not be installed; on success the app
  /// quits and the new build starts.
  Future<void> installAndRestart() async {
    final current = state;
    if (current is! UpdateReady) return;
    state = UpdateInstalling(current.update);
    try {
      final installed = await _installUpdate(current.stagedPath);
      if (installed case Err(:final failure)) {
        state = _failed(current.update, failure.message, failure.cause);
      }
    } catch (error) {
      state = _failed(current.update, 'Installing the update failed', error);
    }
  }

  UpdateFailed _failed(AvailableUpdate update, String message, Object? cause) {
    appTalker.warning('Update: $message${cause == null ? '' : ' ($cause)'}');
    return UpdateFailed(update, message);
  }
}

/// Kept alive on purpose: the hourly check and a download in progress must
/// outlive whichever widget happens to be watching.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(
      () => UpdateController(
        checkForUpdate: getIt<CheckForUpdate>(),
        downloadUpdate: getIt<DownloadUpdate>(),
        installUpdate: getIt<InstallUpdate>(),
      ),
    );
