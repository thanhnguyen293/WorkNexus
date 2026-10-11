import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_http_datasource.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    // flutter_test fakes HTTP; this test talks to a real local server.
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      // An upload is read but never answered, so the test can stop it.
      if (request.method == 'POST') {
        await request.drain<void>();
        return;
      }
      final response = request.response
        ..bufferOutput = false
        ..contentLength = 1024 * 1024;
      // Trickles the file out, so the test can stop it midway.
      for (var i = 0; i < 1024; i++) {
        response.add(List.filled(1024, 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await response.close().catchError((_) {});
    });
  });

  tearDown(() => server.close(force: true));

  test('cancelling a download stops it with a CancelledFailure', () async {
    final cancel = Completer<void>();
    final started = Completer<void>();
    final download = const XxdHttpDatasource(clientVersion: '9.0').download(
      Uri.parse('http://127.0.0.1:${server.port}/file'),
      cancel: cancel.future,
      onProgress: (received, total) {
        if (!started.isCompleted) started.complete();
      },
    );
    await started.future.timeout(const Duration(seconds: 3));
    cancel.complete();

    final result = await download.timeout(const Duration(seconds: 3));
    expect(result, isA<Err<dynamic>>());
    expect((result as Err).failure, isA<CancelledFailure>());
  });

  test('cancelling an upload stops it with a CancelledFailure', () async {
    final cancel = Completer<void>();
    final sent = Completer<void>();
    final upload = const XxdHttpDatasource(clientVersion: '9.0').upload(
      server: Uri.parse('http://127.0.0.1:${server.port}'),
      token: 't',
      userId: 1,
      chatGid: 'g1',
      fileName: 'a.bin',
      bytes: Uint8List(256 * 1024),
      cancel: cancel.future,
      onProgress: (p) {
        if (p > 0.5 && !sent.isCompleted) sent.complete();
      },
    );
    await sent.future.timeout(const Duration(seconds: 3));
    cancel.complete();

    final result = await upload.timeout(const Duration(seconds: 3));
    expect((result as Err).failure, isA<CancelledFailure>());
  });
}
