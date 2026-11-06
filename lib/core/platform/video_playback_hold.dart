import 'package:video_player/video_player.dart';

import 'media_playback_priority.dart';

/// Holds [priority] while [player] plays (or buffers) and has not loaded
/// all of its video yet — a stream still downloading — so background video
/// transfers pause meanwhile. A local file is loaded at once and holds
/// nothing. Returns the callback that stops watching (call it on dispose).
void Function() holdWhileLoading(
  VideoPlayerController player, {
  MediaPlaybackPriority? priority,
}) {
  final gate = priority ?? mediaPlaybackPriority;
  void Function()? release;
  void update() {
    final v = player.value;
    final loading =
        v.isInitialized && (v.isPlaying || v.isBuffering) && !_fullyLoaded(v);
    if (loading && release == null) {
      release = gate.hold();
    } else if (!loading) {
      release?.call();
      release = null;
    }
  }

  player.addListener(update);
  update();
  return () {
    player.removeListener(update);
    release?.call();
    release = null;
  };
}

/// Whether the buffered ranges cover the whole video.
bool _fullyLoaded(VideoPlayerValue v) {
  if (v.duration <= Duration.zero || v.buffered.isEmpty) return false;
  const slack = Duration(milliseconds: 500);
  return v.buffered.any((r) => r.start <= slack && r.end >= v.duration - slack);
}
