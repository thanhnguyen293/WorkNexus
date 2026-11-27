import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:synchronized/synchronized.dart';

import '../cache/lru_cache_singleton.dart';
import '../ext/file_ext.dart';
import '../ext/log_ext.dart';
import '../global/config.dart';
import 'download_status.dart';
import 'download_task.dart';

/// The maximum number of isolates allowed in the pool.
const int MAX_POOL_SIZE = 1;

/// The maximum task priority value.
const int MAX_TASK_PRIORITY = 9999;

/// The minimum interval (in milliseconds) for updating download progress.
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

class DownloadPool {
  /// Lock for synchronizing access to the pool to ensure thread safety.
  final Lock _lock = Lock();

  /// The maximum number of isolates allowed in the pool.
  final int _poolSize;

  /// List of all download tasks managed by the pool.
  final List<DownloadTask> _taskList = [];

  /// HTTP client used for downloading files.
  late final Dio _client;

  /// Stream controller for broadcasting download task updates to listeners.
  late final StreamController<DownloadTask> _streamController;

  /// The last time progress was updated.
  DateTime _progressTime = DateTime.now();

  /// [WorkNexus patch] Tasks below this priority are held: not started, and
  /// paused if running. 0 holds nothing.
  int _minPriority = 0;

  /// Whether a [roundTask] is already queued by [scheduleRound].
  bool _roundScheduled = false;

  /// Constructs a [DownloadPool] with the specified [poolSize].
  /// Throws an [ArgumentError] if the pool size is less than or equal to zero.
  DownloadPool({int poolSize = MAX_POOL_SIZE}) : _poolSize = poolSize {
    if (_poolSize <= 0) {
      throw ArgumentError('Pool size must be greater than 0');
    }
    _client = Dio()..httpClientAdapter = _createHttpClientAdapter();
    _streamController = StreamController.broadcast();
  }

  /// [WorkNexus patch] Holds every task below [value] (see [_minPriority]):
  /// background downloads give way while a player waits for data.
  int get minPriority => _minPriority;

  set minPriority(int value) {
    if (value == _minPriority) return;
    _minPriority = value;
    scheduleRound();
  }

  /// [WorkNexus patch] Runs [roundTask] on the next event-loop turn, once for
  /// any number of calls before it. Upstream debounced it by 500 ms, which
  /// delayed the start of every segment by half a second.
  void scheduleRound() {
    if (_roundScheduled) return;
    _roundScheduled = true;
    Timer.run(() {
      _roundScheduled = false;
      roundTask();
    });
  }

  /// Returns the stream controller for task updates.
  StreamController<DownloadTask> get streamController => _streamController;

  /// Returns the list of all tasks in the pool.
  List<DownloadTask> get taskList => _taskList;

  /// Returns the list of tasks that are not currently downloading.
  List<DownloadTask> get prepareTasks => _taskList
      .where((task) => task.status != DownloadStatus.DOWNLOADING)
      .toList();

  /// Returns the list of tasks that are currently downloading.
  List<DownloadTask> get downloadingTasks => _taskList
      .where((task) => task.status == DownloadStatus.DOWNLOADING)
      .toList();

  HttpClientAdapter _createHttpClientAdapter() {
    try {
      // [WorkNexus patch] NSURLSession opens 6 connections per host by
      // default (4 on iOS); a larger pool's extra requests queued inside it,
      // where priorities don't reach — after a seek, the segment the player
      // was blocked on waited behind look-ahead downloads. The slack covers
      // cancelled requests still closing.
      return NativeAdapter(
        createCupertinoConfiguration: () =>
            URLSessionConfiguration.defaultSessionConfiguration()
              ..httpMaximumConnectionsPerHost = _poolSize + 2,
      );
    } catch (error) {
      // Some simulator/runtime combinations cannot load native_dio_adapter's
      // Objective-C dynamic library. Falling back keeps VideoProxy usable; the
      // default Dio adapter still supports the Range requests used here.
      logW(
          '[DownloadPool] NativeAdapter unavailable, fallback to Dio default: $error');
      return HttpClientAdapter();
    }
  }

  /// Finds a task in the pool by its [taskId].
  DownloadTask? findTaskById(String taskId) =>
      _taskList.where((task) => task.id == taskId).firstOrNull;

  /// Finds a task in the pool by its [url].
  DownloadTask? findTaskByUrl(String url) =>
      _taskList.where((task) => task.url == url).firstOrNull;

  /// Adds a new [task] to the pool, creating a cache directory if needed.
  Future<DownloadTask> addTask(DownloadTask task) async {
    logV('[DownloadPool] addTask: ${task.toString()}');
    DownloadTask? existTask =
        _taskList.where((e) => e.matchUrl == task.matchUrl).firstOrNull;
    if (existTask != null) {
      _promoteTaskPriorityIfNeeded(existTask, task);
      return existTask;
    }
    if (task.cacheDir.isEmpty) {
      String cachePath = await FileExt.createCachePath();
      task.cacheDir = cachePath;
    }
    _taskList.add(task);
    return task;
  }

  /// Executes a [task], replacing any existing lower-priority task with the same cache key.
  /// Schedules the isolate pool for task execution.
  Future<DownloadTask> executeTask(DownloadTask task) async {
    DownloadTask? existTask =
        _taskList.where((e) => e.matchUrl == task.matchUrl).firstOrNull;
    if (existTask != null) {
      _promoteTaskPriorityIfNeeded(existTask, task);
    } else if (existTask == null) {
      await addTask(task);
    }
    scheduleRound();
    return task;
  }

  void _promoteTaskPriorityIfNeeded(
    DownloadTask existingTask,
    DownloadTask incomingTask,
  ) {
    if (existingTask.priority >= incomingTask.priority) return;

    // Keep the existing task object so listeners waiting on this cache key
    // continue to observe the same download, but promote it in the scheduler.
    existingTask.priority = incomingTask.priority;
    if (existingTask.status == DownloadStatus.PAUSED) {
      existingTask.status = DownloadStatus.IDLE;
    }
    scheduleRound();
  }

  void updateTaskById(String taskId, DownloadStatus status) {
    final task = findTaskById(taskId);
    if (task != null) _updateTask(task, status);
  }

  void updateTaskByUrl(String url, DownloadStatus status) {
    final task = findTaskByUrl(url);
    if (task != null) _updateTask(task, status);
  }

  /// [WorkNexus patch] A pause or cancel stops the request at once (upstream
  /// waited for its next progress event, and a cancel never stopped it), and
  /// a resume goes through the scheduler: upstream started the request
  /// directly, even for a task already downloading, so two requests wrote
  /// the same `.tmp` file.
  void _updateTask(DownloadTask task, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.DOWNLOADING:
        if (task.status != DownloadStatus.DOWNLOADING) {
          task.status = DownloadStatus.IDLE;
        }
        scheduleRound();
      case DownloadStatus.PAUSED:
        task.status = DownloadStatus.PAUSED;
        task.cancelToken?.cancel();
      case DownloadStatus.COMPLETED ||
            DownloadStatus.FAILED ||
            DownloadStatus.CANCELLED:
        task.status = status;
        task.cancelToken?.cancel();
        _taskList.remove(task);
        _notifyTask(task);
        scheduleRound();
      case DownloadStatus.IDLE:
        task.status = status;
    }
  }

  /// Schedules the pool to run tasks, ensuring only one thread runs this logic at a time.
  ///
  /// [WorkNexus patch] Free slots go to the highest-priority tasks at or
  /// above [_minPriority]; a task below it that is running is paused (its
  /// `.tmp` file kept to resume from). A running task gives up its slot only
  /// to a segment a player is blocked on ([Config.playbackPriority]) —
  /// upstream preempted it for any higher priority, so every look-ahead
  /// segment a player queued restarted some background download.
  Future<void> roundTask() async {
    await _lock.synchronized(() async {
      if (_taskList.isEmpty) return;
      _taskList.sort(_byPriority);
      for (final task in [..._taskList]) {
        if (task.status == DownloadStatus.DOWNLOADING &&
            task.priority < _minPriority) {
          _pause(task);
        }
      }
      var running = downloadingTasks.length;
      for (final task in [..._taskList]) {
        if (task.status == DownloadStatus.DOWNLOADING) continue;
        if (task.priority < _minPriority) continue;
        if (running < _poolSize) {
          running++;
          _start(task);
          continue;
        }
        if (task.priority < Config.playbackPriority) break;
        // The lowest-priority download below it (the list is sorted).
        final DownloadTask? victim = _taskList
            .where(
              (t) =>
                  t.status == DownloadStatus.DOWNLOADING &&
                  t.priority < task.priority,
            )
            .lastOrNull;
        if (victim == null) break;
        _pause(victim);
        _start(task);
      }
    });
  }

  void _start(DownloadTask task) {
    task.status = DownloadStatus.DOWNLOADING;
    _notifyTask(task);
    unawaited(_download(task));
  }

  void _pause(DownloadTask task) {
    task.status = DownloadStatus.PAUSED;
    task.cancelToken?.cancel();
    _notifyTask(task);
  }

  /// Highest priority first; among equals a running task before a waiting
  /// one (so an unstable sort never swaps a download for its twin), then the
  /// oldest first.
  static int _byPriority(DownloadTask a, DownloadTask b) {
    final byPriority = b.priority - a.priority;
    if (byPriority != 0) return byPriority;
    final aRuns = a.status == DownloadStatus.DOWNLOADING ? 0 : 1;
    final bRuns = b.status == DownloadStatus.DOWNLOADING ? 0 : 1;
    if (aRuns != bRuns) return aRuns - bRuns;
    return (int.tryParse(a.id) ?? 0) - (int.tryParse(b.id) ?? 0);
  }

  /// [WorkNexus patch] One request per task at a time, resuming from the
  /// bytes its `.tmp` file really holds. Upstream added up byte counters on
  /// each pause and double-counted on the second one, so the resumed request
  /// skipped bytes and a corrupt segment was cached.
  Future<void> _download(DownloadTask task) async {
    if (task.inFlight) return;
    task.inFlight = true;
    final DateTime startTime = DateTime.now();
    final CancelToken cancelToken = task.cancelToken = CancelToken();
    // Write to a temp file and atomically rename it to the final name once the
    // download completes. An interruption (or a killed process) leaves only a
    // `.tmp` file, never a half-written segment under its final name (`.tmp` is
    // skipped during startup restore — see LruCacheSingleton._storageInit).
    final String tmpPath = '${task.savePath}.tmp';
    var retry = false;
    try {
      final File tmpFile = File(tmpPath);
      var have = await tmpFile.exists() ? await tmpFile.length() : 0;
      final int? end = task.endRange;
      if (end != null && have >= end - task.startRange + 1) {
        // Whole or overlong: nothing to resume — fetch it again.
        await tmpFile.delete();
        have = 0;
      }
      task.cachedBytes = have;
      task.downloadedBytes = have;
      await _client.download(
        task.url,
        tmpPath,
        cancelToken: cancelToken,
        fileAccessMode: have > 0 ? FileAccessMode.append : FileAccessMode.write,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          if (task.status != DownloadStatus.DOWNLOADING) {
            cancelToken.cancel();
            return;
          }
          _downloadProgress(task, received, total);
        },
        options: Options(headers: _downloadHeader(task)),
      );
      await _downloadResponse(task, startTime);
    } catch (error) {
      retry = _downloadError(task, error);
    } finally {
      task.inFlight = false;
      if (identical(task.cancelToken, cancelToken)) task.cancelToken = null;
    }
    // A retry, or asked to run again while this request was still unwinding
    // from a pause: start it now that the `.tmp` file has settled.
    final rerun = cancelToken.isCancelled &&
        task.status == DownloadStatus.DOWNLOADING &&
        _taskList.contains(task);
    if (retry || rerun) unawaited(_download(task));
  }

  Map<String, Object> _downloadHeader(DownloadTask task) {
    Map<String, Object> headers = {};
    // Set up HTTP Range header for resuming or partial downloads.
    String range = '';
    if (task.startRange > 0 || task.cachedBytes > 0) {
      range = 'bytes=${task.startRange + task.cachedBytes}-';
    }
    if (task.endRange != null) {
      if (range.isEmpty) range = 'bytes=0-';
      range += '${task.endRange}';
    }
    if (range.isNotEmpty) {
      headers.putIfAbsent('Range', () => range);
    }
    // Add custom headers except 'host' and 'range'.
    if (task.headers != null) {
      task.headers!.forEach((key, value) {
        String keyLower = key.toLowerCase();
        if (keyLower == 'host' || keyLower == 'range') return;
        headers.putIfAbsent(key, () => value);
      });
    }
    return headers;
  }

  void _downloadProgress(DownloadTask task, int received, int total) {
    // Calculate the total file size
    task.downloadedBytes = task.cachedBytes + received;
    task.totalBytes = total == -1 ? 0 : (task.cachedBytes + total);

    // Calculate the interval between the current time and the last update time
    final currentTime = DateTime.now();
    final timeDiff = currentTime.difference(_progressTime).inMilliseconds;

    // If the time interval exceeds the specified minimum update interval,
    // or the download is complete, then update progress
    if (task.status == DownloadStatus.DOWNLOADING &&
        timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
      _updateProgress(task);
      _progressTime = currentTime;
    }
  }

  Future<void> _downloadResponse(DownloadTask task, DateTime startTime) async {
    final File tmpFile = File('${task.savePath}.tmp');
    final File saveFile = File(task.savePath);
    // Atomic publish: rename the completed `.tmp` to the final name. On Windows,
    // renaming onto an existing path throws, so delete any stale file first. This
    // guarantees the final name always points to a complete segment.
    if (await saveFile.exists()) {
      await saveFile.delete();
    }
    await tmpFile.rename(task.savePath);
    task.progress = 1;
    task.data = await saveFile.readAsBytes();
    try {
      // [WorkNexus patch] Cached before the task leaves the list: a reader
      // that no longer finds the task must find the data. Upstream removed it
      // first, and a player asking in between downloaded the segment again.
      await LruCacheSingleton().memoryPut(
        task.matchUrl,
        Uint8List.fromList(task.data),
      );
      await LruCacheSingleton().storagePut(task.matchUrl, saveFile);
    } catch (e) {
      // Cache registration is an optimization after the network download has
      // succeeded. Do not turn cache bookkeeping failures into download errors.
      logE('[DownloadPool] Cache registration failed: $e');
    }
    if (_taskList.contains(task)) _updateTask(task, DownloadStatus.COMPLETED);
    int duration = DateTime.now().difference(startTime).inSeconds;
    logV('[DownloadPool] Download done time: $duration s: ${task.toString()}');
  }

  /// Returns whether to retry. A pause or cancel keeps the partial `.tmp`
  /// file — a later request for the segment resumes from it — while a real
  /// failure deletes it.
  bool _downloadError(DownloadTask task, dynamic error) {
    File tmpFile = File('${task.savePath}.tmp');
    if (error is DioException && CancelToken.isCancel(error)) {
      logV('[DownloadPool] Download ${task.status.name}: ${task.url}');
      return false;
    }
    if (tmpFile.existsSync()) tmpFile.deleteSync();
    logV('[DownloadPool] Download error: $error');
    if (error is DioException && error.response?.statusCode == 416) {
      task.retryTimes = 0;
    }
    if (!_taskList.contains(task)) return false;
    if (task.retryTimes > 0) {
      logV('[DownloadPool] Download retry ${task.retryTimes}: ${task.uri}');
      task.retryTimes--;
      return true;
    }
    _updateTask(task, DownloadStatus.FAILED);
    return false;
  }

  void _updateProgress(DownloadTask task) {
    if (task.totalBytes > 0) {
      task.progress = task.downloadedBytes / task.totalBytes;
    }
    _notifyTask(task);
    logV("[DownloadPool] DOWNLOADING ${task.toString()}");
  }

  void _notifyTask(DownloadTask task) {
    if (_streamController.isClosed) return;
    _streamController.sink.add(task);
  }

  void dispose() {
    // Force-cancel all in-flight download requests directly.
    // When the app returns from background, TCP connections are dead and
    // Dio's onReceiveProgress callback will never fire, so we must cancel
    // tokens explicitly to unblock any pending futures.
    for (final task in _taskList) {
      task.cancelToken?.cancel('DownloadPool disposed');
    }
    _taskList.clear();
    _streamController.close();
    _client.close();
    DownloadTask.resetId();
  }
}
