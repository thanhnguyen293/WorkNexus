# WorkNexus patches to flutter_video_caching 1.1.6

Vendored from [pub.dev 1.1.6](https://pub.dev/packages/flutter_video_caching/versions/1.1.6)
(MIT, see `LICENSE`). Every change is marked `[WorkNexus patch]` in the source.
Only the MP4 path and the download pool are touched; HLS is as upstream.

Measured against a fake origin capped at 0.4 MB/s per connection (a ZenTao
server's rate), playing a 24 MB recording: upstream delivered ~0.47 MB/s, the
patched copy ~2.1 MB/s.

| Problem in 1.1.6 | Fix | Files |
|---|---|---|
| A player kept only 2 segments downloading (hard-coded), whatever the pool size | `Config.lookAheadSegments`, set via `VideoProxy.init(lookAheadSegments:)` | `config.dart`, `video_proxy.dart`, `url_parser_mp4.dart` |
| A finished segment left the task list before it was cached, so a player asking in between downloaded it again | Cache first, then complete the task | `download_pool.dart` |
| Each task started 500 ms late (debounced scheduler) | `scheduleRound()` runs on the next event-loop turn | `download_pool.dart` |
| A second pause double-counted the bytes already fetched; the resumed request skipped bytes and a corrupt segment was cached | Resume from the `.tmp` file's real length | `download_pool.dart` |
| Resuming a running task started a second request writing the same `.tmp` | One request per task (`DownloadTask.inFlight`); resume goes through the scheduler | `download_pool.dart`, `download_task.dart` |
| Pause/cancel only took effect at the next progress event; cancel never stopped the request | Both cancel the request at once | `download_pool.dart` |
| A paused task came back at the scheduler's next round, so background work could not be held | `DownloadManager.holdBelow(priority)`: tasks below it neither start nor run | `download_pool.dart`, `download_manager.dart` |
| Any higher-priority task preempted a running one, so every look-ahead segment restarted some precache | Only a segment a player is blocked on (`Config.playbackPriority`) preempts | `download_pool.dart` |
| A player waiting on an already-queued segment polled forever, without raising it: a held precache stalled playback, and a failed one hung it | `_awaitSegment` raises it to playback priority and gives up when it fails or the player leaves | `url_parser_mp4.dart` |
| Look-ahead segments had the precache's priority | They get `Config.lookAheadPriority` (2); an existing precache of one is raised | `url_parser_mp4.dart` |
| The proxy stopped reading a connection while serving it, so a closed video downloaded on to its end | The connection is watched (read side and write errors); the serve loop stops when the player leaves | `local_proxy_server.dart`, `socket_ext.dart`, `url_parser_mp4.dart` |
| Flushing to a player that reset the connection never completed, so the handler hung | No flush to a gone player; its socket is destroyed | `url_parser_mp4.dart`, `socket_ext.dart`, `local_proxy_server.dart` |
| A closed video's queued downloads ran on | When a video's last connection closes, its player downloads drop to background priority at once and are cancelled after `Config.abandonGrace` unless a player raises them again | `url_parser_mp4.dart`, `download_manager.dart` |
| `UrlParserMp4.download` waited forever when the task failed or was cancelled | Stops on those too | `url_parser_mp4.dart` |
| Callers had to send their own HEAD for the length | `UrlParserMp4.contentLength` (was private) | `url_parser_mp4.dart` |

Regression tests: `test/core/platform/video_stream_proxy_streaming_test.dart`.
