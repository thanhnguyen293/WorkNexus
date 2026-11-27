import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart'
    show DownloadStatus, DownloadTask, VideoProxy;
import 'package:flutter_video_caching/global/config.dart';
import 'package:work_nexus/core/platform/media_playback_priority.dart';
import 'package:work_nexus/core/platform/video_stream_proxy.dart';

const _mb = 1000 * 1000;

/// Byte [i] of every fake video, so what a player receives can be checked.
int _byteAt(int i) => (i * 31 + i ~/ 977) & 0xff;

/// A video server that sends each request at 1 MB/s — like a self-hosted
/// ZenTao, slow per connection and faster in parallel — and logs each GET's
/// range start. `/<name>/<n>` is an n MB video.
class _Origin {
  static const _chunk = 50 * 1000;
  static const _tick = Duration(milliseconds: 50);

  late final HttpServer _server;
  final clock = Stopwatch()..start();
  final _gets = <String, List<({int start, int atMs})>>{};
  var _active = 0;
  var maxActive = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((r) => unawaited(_serve(r)));
  }

  Future<void> close() => _server.close(force: true);

  Uri uri(String name, int mb) =>
      Uri.parse('http://127.0.0.1:${_server.port}/$name/$mb');

  List<({int start, int atMs})> gets(String name) => [
    for (final e in _gets.entries)
      if (e.key.startsWith('/$name/')) ...e.value,
  ];

  Future<void> _serve(HttpRequest req) async {
    final size = int.parse(req.uri.pathSegments.last) * _mb;
    final m = RegExp(
      r'bytes=(\d+)-(\d*)',
    ).firstMatch(req.headers.value('range') ?? '');
    final start = m == null ? 0 : int.parse(m.group(1)!);
    final asked = m?.group(2) ?? '';
    final end = asked.isEmpty ? size - 1 : min(int.parse(asked), size - 1);
    final res = req.response
      ..headers.set('accept-ranges', 'bytes')
      ..contentLength = end - start + 1;
    if (m != null) {
      res
        ..statusCode = HttpStatus.partialContent
        ..headers.set('content-range', 'bytes $start-$end/$size');
    }
    if (req.method == 'HEAD') return res.close();
    (_gets[req.uri.path] ??= []).add((
      start: start,
      atMs: clock.elapsedMilliseconds,
    ));
    maxActive = max(maxActive, ++_active);
    try {
      for (var p = start; p <= end; p += _chunk) {
        final n = min(_chunk, end + 1 - p);
        res.add(
          Uint8List.fromList([for (var k = 0; k < n; k++) _byteAt(p + k)]),
        );
        await res.flush();
        await Future<void>.delayed(_tick);
      }
      await res.close();
    } on Object {
      // The proxy cancelled this request.
    } finally {
      _active--;
    }
  }
}

/// Plays [uri] from byte [from] like a player; stops once [stopAfter] bytes
/// arrived. Returns how many arrived and the first wrong byte's offset in
/// the file (-1: none).
Future<({int bytes, int firstBad})> _play(
  Uri uri, {
  int from = 0,
  int? stopAfter,
}) async {
  final client = HttpClient();
  var got = 0;
  var bad = -1;
  try {
    final req = await client.getUrl(uri);
    req.headers.set('range', 'bytes=$from-');
    final res = await req.close();
    await for (final chunk in res.timeout(const Duration(seconds: 15))) {
      for (var k = 0; k < chunk.length && bad < 0; k++) {
        if (chunk[k] != _byteAt(from + got + k)) bad = from + got + k;
      }
      got += chunk.length;
      if (stopAfter != null && got >= stopAfter) break;
    }
  } finally {
    client.close(force: true);
  }
  return (bytes: got, firstBad: bad);
}

List<DownloadTask> _tasksOf(String name) => [
  for (final t in VideoProxy.downloadManager.allTasks)
    if (t.url.contains('/$name/')) t,
];

Future<void> _until(bool Function() done) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > const Duration(seconds: 10)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late _Origin origin;
  late Directory dir;
  late MediaPlaybackPriority priority;
  late VideoStreamProxy proxy;

  setUpAll(() async {
    origin = _Origin();
    await origin.start();
    dir = await Directory.systemTemp.createTemp('wn_stream_play_');
    priority = MediaPlaybackPriority();
    proxy = VideoStreamProxy(cacheDir: dir, priority: priority);
    Config.abandonGrace = const Duration(milliseconds: 300);
  });

  tearDownAll(() async {
    await origin.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Uri> local(String name, int mb) async =>
      (await proxy.localUri(origin.uri(name, mb)))!;

  test('a playing video is fetched several segments at once, each once, '
      'and arrives intact', () async {
    final played = await _play(await local('intact', 8));

    expect(played, (bytes: 8 * _mb, firstBad: -1));
    final starts = origin.gets('intact').map((g) => g.start).toList();
    expect(starts.toSet(), hasLength(starts.length), reason: 'no refetch');
    // Upstream kept 2 segments ahead: at most 3 requests at a time.
    expect(origin.maxActive, greaterThan(3));
  });

  test(
    'a closed video stops fetching instead of loading on to its end',
    () async {
      await _play(await local('closed', 24), stopAfter: _mb);
      final closedAt = origin.clock.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // At most the first wave (segments 0–7, done by the close) and the
      // window ahead of where the proxy had sent to (8 more) — not all 24.
      final gets = origin.gets('closed');
      expect(gets.length, lessThanOrEqualTo(16));
      expect(gets.where((g) => g.atMs > closedAt + 500), isEmpty);
      expect(_tasksOf('closed'), isEmpty, reason: 'its downloads cancelled');
    },
  );

  test('a precache pauses while a video loads and resumes, twice, into '
      'intact segments', () async {
    unawaited(proxy.precache(origin.uri('held', 6), const {}));
    await _until(
      () => _tasksOf('held').any((t) => t.status == DownloadStatus.DOWNLOADING),
    );
    for (var i = 0; i < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final release = priority.hold();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        _tasksOf('held').where((t) => t.status == DownloadStatus.DOWNLOADING),
        isEmpty,
      );
      release();
    }
    await _until(() => _tasksOf('held').isEmpty);

    // Upstream double-counted a second pause, resumed past bytes it never
    // got, and cached the broken segment.
    expect(origin.gets('held').where((g) => g.start % _mb != 0), isNotEmpty);
    expect(await _play(await local('held', 6)), (bytes: 6 * _mb, firstBad: -1));
  });

  test(
    'a player is not kept waiting on a held precache of its video',
    () async {
      unawaited(proxy.precache(origin.uri('shared', 4), const {}));
      await _until(() => _tasksOf('shared').isNotEmpty);
      // The hold a loading player takes, which holds precaches.
      final release = priority.hold();
      addTearDown(release);

      expect(await _play(await local('shared', 4)), (
        bytes: 4 * _mb,
        firstBad: -1,
      ));
    },
  );

  test('a seek gets its new position\'s window at once', () async {
    // Playing and still loading: the hold the player takes.
    final release = priority.hold();
    addTearDown(release);
    await _play(await local('seek', 24), stopAfter: 2 * _mb);
    final seekAt = origin.clock.elapsedMilliseconds;

    final played = await _play(
      await local('seek', 24),
      from: 16 * _mb,
      stopAfter: 2 * _mb,
    );

    expect(played.bytes, greaterThanOrEqualTo(2 * _mb));
    expect(played.firstBad, -1);
    // Upstream counted the old position's downloads in the window, and
    // NSURLSession queued requests past its 6 per host: the new position got
    // its first segment only after the old ones finished.
    final early = origin
        .gets('seek')
        .where((g) => g.start >= 16 * _mb && g.atMs < seekAt + 400);
    expect(early.length, greaterThanOrEqualTo(4));
  });
}
