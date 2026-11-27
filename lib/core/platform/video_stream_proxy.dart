import 'dart:async';
import 'dart:io';

import 'package:flutter_video_caching/flutter_video_caching.dart'
    show
        DownloadTask,
        LruCacheSingleton,
        UrlExt,
        UrlMatcherDefault,
        UrlParserMp4,
        VideoCaching,
        VideoProxy;

import 'directory_size.dart';
import 'media_playback_priority.dart';

/// A localhost caching proxy (flutter_video_caching) a player streams a
/// remote video through: it plays while the rest downloads in segments, and
/// what was fetched is kept on disk for the next play. The player's headers
/// are forwarded upstream, so a provider session reaches the server.
///
/// Started on first use, not at launch: most sessions never play a video.
class VideoStreamProxy {
  VideoStreamProxy({
    Directory? cacheDir,
    this.maxStorageMb = 1024,
    MediaPlaybackPriority? priority,
  }) : _cacheDir =
           cacheDir ?? Directory('$_tempRoot/worknexus_video_stream_v2'),
       // Segments the old downloader resumed could be missing bytes (it
       // double-counted a twice-paused download), so its cache is dropped.
       _legacyDir = cacheDir == null
           ? Directory('$_tempRoot/worknexus_video_stream')
           : null,
       _priority = priority ?? mediaPlaybackPriority;

  static String get _tempRoot => Directory.systemTemp.path;

  final Directory _cacheDir;
  final Directory? _legacyDir;
  final int maxStorageMb;
  final MediaPlaybackPriority _priority;
  Future<bool>? _started;

  /// The precache's priority in the download pool; a player's own requests
  /// rank higher, so holding these never stalls the video being watched.
  static const _backgroundPriority = 1;

  /// [origin] rewritten to go through the proxy; null when the proxy can't
  /// start (the caller then downloads the whole file instead).
  Future<Uri?> localUri(Uri origin) async {
    if (!await (_started ??= _start())) return null;
    return origin.toString().toLocalUri();
  }

  /// Segment size handed to the proxy, in its (decimal) megabytes.
  static const _segmentMb = 1;
  static const _segmentBytes = _segmentMb * 1000 * 1000;

  /// Fetches the opening [segments] of [origin] and its last one into the
  /// cache, queued behind anything a player is waiting for. A phone screen
  /// recording keeps its index (moov) at the end, and a player needs that
  /// before the first frame — so with both ends cached it starts at once.
  Future<void> precache(
    Uri origin,
    Map<String, String> headers, {
    int segments = 2,
  }) async {
    if (!await (_started ??= _start())) return;
    // Not while a playing video is still loading.
    await _priority.idle();
    try {
      await VideoCaching.precache(
        origin.toString(),
        headers: headers,
        cacheSegments: segments,
        // Not `false`: that only lists the tasks without starting the
        // downloader, and a player then waits on them forever.
      );
      final parser = UrlParserMp4();
      // Stored by the precache above: no second HEAD.
      final length = await parser.contentLength(origin, headers);
      if (length <= _segmentBytes * segments) return;
      // Keyed as playback asks for it: segment-aligned, clamped to the end.
      final last = (length - 1) - (length - 1) % _segmentBytes;
      // Started, not awaited: it completes in the background (see above).
      unawaited(
        parser.download(
          DownloadTask(
            uri: origin,
            startRange: last,
            endRange: length - 1,
            headers: headers,
          ),
        ),
      );
    } on Exception {
      // A warm-up only: playback fetches whatever is missing.
    }
  }

  /// Holds the precache while a playing video loads (the pool neither starts
  /// nor runs it), and lets it go after.
  void _onPlayback(bool busy) {
    VideoProxy.downloadManager.holdBelow(busy ? _backgroundPriority + 1 : 0);
  }

  /// Bytes of video kept on disk.
  Future<int> sizeBytes() => directoryBytes(_cacheDir);

  /// Drops every kept video.
  Future<void> clear() async {
    final started = _started;
    if (started != null && await started) {
      // Running: clear through the package, so its index forgets the files.
      final cache = LruCacheSingleton();
      await cache.memoryClear();
      await cache.storageClear();
    } else if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
    }
  }

  Future<bool> _start() async {
    try {
      await _cacheDir.create(recursive: true);
      final legacy = _legacyDir;
      if (legacy != null && await legacy.exists()) {
        await legacy.delete(recursive: true);
      }
      await VideoProxy.init(
        cacheDir: _cacheDir.path,
        maxStorageCacheSize: maxStorageMb,
        // The proxy hands a segment to the player only once all of it has
        // arrived, and a self-hosted server is slow per connection (ZenTao:
        // ~0.4 MB/s each, more in parallel). Small segments fetched wide get
        // the first frame out sooner: cold start of a 39 MB recording went
        // from ~10-15 s (2 MB × 4) to ~5.5-7 s (1 MB × 8).
        segmentSize: _segmentMb,
        maxConcurrentDownloads: 8,
        // The playing video's own window: upstream fetched 2 segments at a
        // time (~0.5 MB/s here), below a phone recording's ~1.8 MB/s.
        lookAheadSegments: 8,
        urlMatcher: _AnyVideoIsMp4(),
      );
      _priority.changes.listen(_onPlayback);
      return true;
    } on Exception {
      // Retried on the next video rather than never.
      _started = null;
      return false;
    }
  }
}

/// Only videos are sent through the proxy, and ZenTao stores uploads without
/// an extension (`data/upload/1/202611/0416…`) — so serve every non-HLS URL
/// the MP4 way (byte-range segments) rather than by its file name.
class _AnyVideoIsMp4 extends UrlMatcherDefault {
  @override
  bool matchMp4(Uri uri) => !matchM3u8(uri);
}
