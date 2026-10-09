import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/app_release.dart';

part 'update_state.freezed.dart';

/// Where the background updater is. Checking and failed downloads stay
/// [UpdateIdle]: they are retried on the next check and never bother the user.
@freezed
sealed class UpdateState with _$UpdateState {
  const factory UpdateState.idle() = UpdateIdle;

  const factory UpdateState.downloading(
    AppRelease release, {
    @Default(0) double progress,
  }) = UpdateDownloading;

  /// Downloaded and verified; a restart installs it.
  const factory UpdateState.ready(AppRelease release, String stagedPath) =
      UpdateReady;

  /// The in-app install could not run (e.g. no write access to the app's
  /// folder); the user installs from the release page instead.
  const factory UpdateState.installFailed(
    AppRelease release,
    String stagedPath,
    String message,
  ) = UpdateInstallFailed;
}
