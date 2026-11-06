import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_video_stream_server.dart';

/// The chat video proxy a player streams through: it forwards ranges to the
/// chat server, and answers a range itself when the server sends the whole
/// file.
void main() {
  final video = List<int>.generate(1000, (i) => i % 256);

  group('ByteRange', () {
    test('parses a single range, open-ended or not', () {
      final open = ByteRange.parse('bytes=100-');
      expect(open?.start, 100);
      expect(open?.end, isNull);
      expect(open?.endFor(1000), 999);
      expect(ByteRange.parse('bytes=0-1')?.endFor(1000), 1);
      expect(ByteRange.parse('bytes=990-2000')?.endFor(1000), 999);
    });

    test('ignores no range, a suffix range or several', () {
      expect(ByteRange.parse(null), isNull);
      expect(ByteRange.parse('bytes=-500'), isNull);
      expect(ByteRange.parse('bytes=0-1,5-9'), isNull);
    });
  });

  test('sliceStream keeps only the asked bytes across chunks', () async {
    final chunks = Stream.fromIterable([
      video.sublist(0, 300),
      video.sublist(300, 700),
      video.sublist(700),
    ]);
    final out = await sliceStream(chunks, 250, 709).expand((c) => c).toList();
    expect(out, video.sublist(250, 710));
  });

  group('proxy', () {
    late HttpServer upstream;
    late ChatVideoStreamServer proxy;
    var honourRange = true;

    setUp(() async {
      proxy = ChatVideoStreamServer();
      upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream.listen((request) async {
        final range = ByteRange.parse(
          request.headers.value(HttpHeaders.rangeHeader),
        );
        final response = request.response;
        if (honourRange && range != null) {
          final end = range.endFor(video.length);
          response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes ${range.start}-$end/${video.length}',
            )
            ..contentLength = end - range.start + 1
            ..add(video.sublist(range.start, end + 1));
        } else {
          response
            ..contentLength = video.length
            ..add(video);
        }
        await response.close();
      });
    });

    tearDown(() async {
      await proxy.close();
      await upstream.close(force: true);
    });

    Future<(int, String?, List<int>)> get(String range) async {
      final local = await proxy.localUri((
        uri: Uri.parse('http://127.0.0.1:${upstream.port}/fileDownload'),
        pin: null,
        contentType: 'video/mp4',
      ), name: 'clip.mp4');
      final client = HttpClient();
      try {
        final request = await client.getUrl(local!);
        request.headers.set(HttpHeaders.rangeHeader, range);
        final response = await request.close();
        final body = await response.expand((c) => c).toList();
        return (
          response.statusCode,
          response.headers.value(HttpHeaders.contentRangeHeader),
          body,
        );
      } finally {
        client.close(force: true);
      }
    }

    test('passes a range the server honours through', () async {
      honourRange = true;
      final (status, contentRange, body) = await get('bytes=10-19');
      expect(status, HttpStatus.partialContent);
      expect(contentRange, 'bytes 10-19/1000');
      expect(body, video.sublist(10, 20));
    });

    test('answers the range itself when the server sends it all', () async {
      honourRange = false;
      final (status, contentRange, body) = await get('bytes=990-');
      expect(status, HttpStatus.partialContent);
      expect(contentRange, 'bytes 990-999/1000');
      expect(body, video.sublist(990));
    });
  });
}
