import 'dart:async';
import 'dart:io';

import 'package:video_player/video_player.dart';

/// Reads a local video's length with the platform player (AVFoundation on
/// macOS, fvp elsewhere) and remembers it in `<video>.duration` next to the
/// file, so each video is probed once.
class VideoDurationReader {
  const VideoDurationReader();

  Future<Duration?> durationOf(String videoPath) async {
    final cache = File('$videoPath.duration');
    try {
      if (await cache.exists()) {
        final ms = int.tryParse((await cache.readAsString()).trim());
        if (ms != null) return Duration(milliseconds: ms);
      }
    } on FileSystemException {
      // Re-probe below.
    }
    final player = VideoPlayerController.file(File(videoPath));
    try {
      await player.initialize().timeout(const Duration(seconds: 15));
      final duration = player.value.duration;
      if (duration <= Duration.zero) return null;
      try {
        await cache.writeAsString('${duration.inMilliseconds}');
      } on FileSystemException {
        // Not cached: probed again next time.
      }
      return duration;
    } on Exception {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
