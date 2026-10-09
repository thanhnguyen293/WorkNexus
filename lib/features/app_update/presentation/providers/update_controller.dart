import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/check_for_update.dart';
import '../../domain/usecases/download_update.dart';
import '../../domain/usecases/install_update.dart';
import 'update_state.dart';

/// The running build's version, baked in by CI for tagged releases
/// (`--dart-define=APP_VERSION=v1.2.3`). Empty for local and nightly builds,
/// which therefore never update themselves.
const appVersion = String.fromEnvironment('APP_VERSION');

/// Checks for a newer stable release shortly after launch and then every few
/// hours, and downloads it in the background so a restart is all it takes.
class UpdateController extends Notifier<UpdateState> {
  static const _firstCheck = Duration(seconds: 20);
  static const _interval = Duration(hours: 6);

  @override
  UpdateState build() {
    if (appVersion.isNotEmpty) {
      final first = Timer(_firstCheck, check);
      final periodic = Timer.periodic(_interval, (_) => check());
      ref.onDispose(() {
        first.cancel();
        periodic.cancel();
      });
    }
    return const UpdateState.idle();
  }

  Future<void> check() async {
    // One update at a time; a ready one waits for the restart.
    if (state is! UpdateIdle) return;
    final checked = await getIt<CheckForUpdate>()(appVersion);
    final release = switch (checked) {
      Ok(:final value) => value,
      Err(:final failure) => _log(failure.message, null),
    };
    if (release == null || state is! UpdateIdle) return;

    appTalker.info('Update: downloading ${release.version}');
    state = UpdateState.downloading(release);
    var shown = 0.0;
    final downloaded = await getIt<DownloadUpdate>()(
      release,
      onProgress: (progress) {
        // Whole percents only: dio reports every chunk.
        if (progress - shown < 0.01) return;
        shown = progress;
        state = UpdateState.downloading(release, progress: progress);
      },
    );
    switch (downloaded) {
      case Ok(:final value):
        appTalker.info('Update: ${release.version} ready at $value');
        state = UpdateState.ready(release, value);
      case Err(:final failure):
        _log(failure.message, failure.cause);
        state = const UpdateState.idle();
    }
  }

  /// Quits and restarts into the downloaded build. Only comes back when the
  /// install could not start.
  Future<void> installAndRestart() async {
    final current = state;
    if (current is! UpdateReady) return;
    final result = await getIt<InstallUpdate>()(current.stagedPath);
    if (result case Err(:final failure)) {
      _log(failure.message, failure.cause);
      state = UpdateState.installFailed(
        current.release,
        current.stagedPath,
        failure.message,
      );
    }
  }

  Null _log(String message, Object? cause) {
    appTalker.warning('Update: $message${cause == null ? '' : ' ($cause)'}');
    return null;
  }
}

/// App-lifetime (not autoDispose): it owns the periodic check timer.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
