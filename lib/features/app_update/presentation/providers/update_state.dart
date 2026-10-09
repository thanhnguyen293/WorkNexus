import '../../domain/entities/available_update.dart';

/// Where the background install of the latest stable release stands. The
/// controller checks on its own, downloads what it finds and then waits in
/// [UpdateReady] until the user restarts into it.
sealed class UpdateState {
  const UpdateState();
}

/// No newer release is known (or none has been looked for yet).
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

/// A newer release is known; [update] describes it.
sealed class UpdatePending extends UpdateState {
  const UpdatePending(this.update);

  final AvailableUpdate update;
}

/// The release carries no verifiable build for this platform, so it can only
/// be fetched by hand from its release page.
class UpdateManual extends UpdatePending {
  const UpdateManual(super.update);
}

class UpdateDownloading extends UpdatePending {
  const UpdateDownloading(super.update, this.progress);

  /// 0..1.
  final double progress;
}

/// Downloaded and verified; installs once the user restarts.
class UpdateReady extends UpdatePending {
  const UpdateReady(super.update, this.stagedPath);

  final String stagedPath;
}

class UpdateInstalling extends UpdatePending {
  const UpdateInstalling(super.update);
}

/// Download or install failed; [message] is for the log, the UI words it.
class UpdateFailed extends UpdatePending {
  const UpdateFailed(super.update, this.message);

  final String message;
}
