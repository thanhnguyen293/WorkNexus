import '../../domain/entities/available_update.dart';

/// Where the in-app install of [AvailableUpdate] stands.
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);

  /// 0..1.
  final double progress;
}

class UpdateInstalling extends UpdateState {
  const UpdateInstalling();
}

/// Download or install failed; [message] is for the log, the dialog words it.
class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);

  final String message;
}
