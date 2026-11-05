import 'dart:async';
import 'dart:io';

import 'package:flutter_video_caching/flutter_video_caching.dart'
    show LruCacheSingleton, UrlExt, UrlMatcherDefault, VideoProxy;

import 'directory_size.dart';

/// A localhost caching proxy (flutter_video_caching) a player streams a
/// remote video through: it plays while the rest downloads in segments, and
/// what was fetched is kept on disk for the next play. The player's headers
/// are forwarded upstream, so a provider session reaches the server.
///
/// Started on first use, not at launch: most sessions never play a video.
class VideoStreamProxy {
  VideoStreamProxy({Directory? cacheDir, this.maxStorageMb = 1024})
    : _cacheDir =
          cacheDir ??
          Directory('${Directory.systemTemp.path}/worknexus_video_stream');

  final Directory _cacheDir;
  final int maxStorageMb;
  Future<bool>? _started;

  /// [origin] rewritten to go through the proxy; null when the proxy can't
  /// start (the caller then downloads the whole file instead).
  Future<Uri?> localUri(Uri origin) async {
    if (!await (_started ??= _start())) return null;
    return origin.toString().toLocalUri();
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
      await VideoProxy.init(
        cacheDir: _cacheDir.path,
        maxStorageCacheSize: maxStorageMb,
        // The proxy hands a segment to the player only once all of it has
        // arrived, and a self-hosted server is slow per connection (ZenTao:
        // ~0.4 MB/s each, more in parallel). Small segments fetched wide get
        // the first frame out sooner: cold start of a 39 MB recording went
        // from ~10-15 s (2 MB × 4) to ~5.5-7 s (1 MB × 8).
        segmentSize: 1,
        maxConcurrentDownloads: 8,
        urlMatcher: _AnyVideoIsMp4(),
      );
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
