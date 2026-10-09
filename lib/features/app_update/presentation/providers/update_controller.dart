import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/available_update.dart';
import '../../domain/usecases/download_update.dart';
import '../../domain/usecases/install_update.dart';
import 'update_state.dart';

/// Downloads an [AvailableUpdate] and restarts into it.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateIdle();

  /// Only returns when the update could not be installed; on success the app
  /// quits and the new build starts.
  Future<void> installAndRestart(AvailableUpdate update) async {
    if (state is UpdateDownloading || state is UpdateInstalling) return;
    try {
      await _run(update);
    } catch (error) {
      // Whatever the repository did not map must still leave the busy state.
      _fail('Update failed unexpectedly', error);
    }
  }

  Future<void> _run(AvailableUpdate update) async {
    state = const UpdateDownloading(0);
    var shown = 0.0;
    final downloaded = await getIt<DownloadUpdate>()(
      update,
      onProgress: (progress) {
        // Whole percents only: dio reports every chunk.
        if (progress - shown < 0.01) return;
        shown = progress;
        state = UpdateDownloading(progress);
      },
    );
    final stagedPath = switch (downloaded) {
      Ok(:final value) => value,
      Err(:final failure) => _fail(failure.message, failure.cause),
    };
    if (stagedPath == null) return;

    state = const UpdateInstalling();
    final installed = await getIt<InstallUpdate>()(stagedPath);
    if (installed case Err(:final failure)) {
      _fail(failure.message, failure.cause);
    }
  }

  Null _fail(String message, Object? cause) {
    appTalker.warning('Update: $message${cause == null ? '' : ' ($cause)'}');
    state = UpdateFailed(message);
    return null;
  }
}

final updateControllerProvider =
    NotifierProvider.autoDispose<UpdateController, UpdateState>(
      UpdateController.new,
    );
