import 'dart:async';
import 'dart:io';

import 'xxd/xxd_tls.dart';

/// A chat video the player streams: the xxd `fileDownload` URL, the pinned
/// certificate fingerprint to reach it with, and its content type.
typedef ChatVideoUpstream = ({Uri uri, String? pin, String contentType});

/// A localhost proxy a video player streams a chat video through, so it
/// starts playing while the rest arrives instead of after a full download.
///
/// The ticket videos' caching proxy cannot serve chat: xxd ships a
/// self-signed certificate that only the pinned client accepts
/// ([createPinnedHttpClient]), and that proxy downloads with the system's
/// TLS. This one forwards each request with the pinned client. A server that
/// ignores `Range` is answered as if it honoured it (the bytes before the
/// asked start are skipped), so a player can still seek and read the index a
/// phone recording keeps at the end.
///
/// Started on first use; nothing is kept on disk (the full download, when
/// the user saves or reopens it, still goes to the chat file cache).
class ChatVideoStreamServer {
  HttpServer? _server;
  Future<HttpServer?>? _starting;
  final _routes = <String, ChatVideoUpstream>{};
  var _next = 0;

  /// A local URL a player can stream [upstream] from; null when the proxy
  /// cannot listen (the caller then downloads the whole file).
  Future<Uri?> localUri(
    ChatVideoUpstream upstream, {
    String name = 'video',
  }) async {
    final server = await (_starting ??= _start());
    if (server == null) return null;
    final id = '${_next++}';
    _routes[id] = upstream;
    // The name keeps its extension: some players pick the format from it.
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      pathSegments: ['v', id, name],
    );
  }

  /// Stops listening and forgets every stream.
  Future<void> close() async {
    _routes.clear();
    final server = _server;
    _server = null;
    _starting = null;
    await server?.close(force: true);
  }

  Future<HttpServer?> _start() async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) => unawaited(_serve(request)));
      return _server = server;
    } on SocketException {
      // Retried on the next video rather than never.
      _starting = null;
      return null;
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    final segments = request.uri.pathSegments;
    final upstream = segments.length >= 2 && segments.first == 'v'
        ? _routes[segments[1]]
        : null;
    if (upstream == null ||
        (request.method != 'GET' && request.method != 'HEAD')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final range = ByteRange.parse(
      request.headers.value(HttpHeaders.rangeHeader),
    );
    final client = createPinnedHttpClient(pinnedFingerprint: upstream.pin);
    try {
      final out = await client.openUrl(request.method, upstream.uri);
      if (range != null) {
        out.headers.set(HttpHeaders.rangeHeader, range.header);
      }
      final up = await out.close();
      final total = up.contentLength;
      response.headers
        ..contentType = ContentType.parse(upstream.contentType)
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (up.statusCode == HttpStatus.partialContent) {
        // The server honoured the range: pass it through.
        response.statusCode = HttpStatus.partialContent;
        final contentRange = up.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null) {
          response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
        }
        if (total >= 0) response.contentLength = total;
        await response.addStream(up);
      } else if (up.statusCode == HttpStatus.ok && range != null && total > 0) {
        // The server sent the whole file: answer the asked range from it.
        final end = range.endFor(total);
        if (range.start >= total || end < range.start) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$total',
          );
        } else {
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes ${range.start}-$end/$total',
          );
          response.contentLength = end - range.start + 1;
          if (request.method == 'GET') {
            await response.addStream(sliceStream(up, range.start, end));
          }
        }
      } else {
        response.statusCode = up.statusCode;
        if (total >= 0) response.contentLength = total;
        await response.addStream(up);
      }
    } on Exception {
      // The player gave up (closed the connection) or xxd failed: the
      // player reports the video as unplayable and the tile offers a
      // download instead.
      try {
        response.statusCode = HttpStatus.badGateway;
      } on StateError {
        // Headers already sent.
      }
    } finally {
      client.close(force: true);
      try {
        await response.close();
      } on Exception {
        // The player already closed the connection.
      }
    }
  }
}

/// A `Range: bytes=start-end` request (end null = to the end of the file).
class ByteRange {
  const ByteRange(this.start, this.end);

  final int start;
  final int? end;

  /// A single `bytes=` range; null for none, a suffix range or several.
  static ByteRange? parse(String? header) {
    final match = RegExp(
      r'^bytes=(\d+)-(\d*)$',
    ).firstMatch(header?.trim() ?? '');
    if (match == null) return null;
    final start = int.parse(match.group(1)!);
    final end = match.group(2)!.isEmpty ? null : int.parse(match.group(2)!);
    return ByteRange(start, end);
  }

  String get header => 'bytes=$start-${end ?? ''}';

  /// The last byte served from a file of [total] bytes.
  int endFor(int total) => switch (end) {
    final e? when e < total => e,
    _ => total - 1,
  };
}

/// The bytes [start]–[end] (inclusive) of [source], dropping what comes
/// before and stopping (cancelling [source]) once [end] is reached.
Stream<List<int>> sliceStream(
  Stream<List<int>> source,
  int start,
  int end,
) async* {
  var offset = 0;
  await for (final chunk in source) {
    final chunkEnd = offset + chunk.length; // exclusive
    if (chunkEnd > start) {
      final from = start > offset ? start - offset : 0;
      final to = end + 1 < chunkEnd ? end + 1 - offset : chunk.length;
      if (to > from) yield chunk.sublist(from, to);
    }
    offset = chunkEnd;
    if (offset > end) return;
  }
}
