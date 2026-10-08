import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import 'xxd_server_info.dart';
import 'xxd_signing.dart';
import 'xxd_tls.dart';

/// Client version reported to xxd. xxd 9.x rejects clients older than 5.0 and
/// its `apiScheme` targets the 9.x client, whose protocol this code mirrors.
const kXxdClientVersion = '9.1.2';

/// HTTPS side of xxd: the `serverInfo` handshake and signed file URLs.
class XxdHttpDatasource {
  const XxdHttpDatasource({
    required this.clientVersion,
    this.lang = 'en',
    this.device = 'desktop',
  });

  /// Reported as `version`; xxd 9.x rejects clients older than 5.0.
  final String clientVersion;
  final String lang;
  final String device;

  /// POST `{server}/serverInfo` with `sysgetserverinfo` and the md5 auth key.
  Future<Result<XxdServerInfo>> fetchServerInfo(XxdCredentials c) async {
    XxdCertificate? rejected;
    final client = createPinnedHttpClient(
      pinnedFingerprint: c.pinnedFingerprint,
      onRejected: (cert) => rejected = cert,
    );
    final body = jsonEncode({
      'method': 'sysgetserverinfo',
      'params': [c.serverName, c.account, xxdPasswordAuthKey(c.password), ''],
      'version': clientVersion,
      'device': device,
      'lang': lang,
    });
    try {
      final request = await client.postUrl(c.server.resolve('/serverInfo'));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write('data=${Uri.encodeQueryComponent(body)}');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response.transform(utf8.decoder).join();
      return _parse(response.statusCode, text);
    } on HandshakeException catch (e) {
      final cert = rejected;
      if (cert != null) return Err(untrustedCertificate(cert, e));
      return Err(NetworkFailure('TLS handshake with xxd failed', cause: e));
    } on SocketException catch (e) {
      return Err(NetworkFailure('Cannot reach the chat server', cause: e));
    } on Exception catch (e) {
      return Err(NetworkFailure('Chat server request failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }

  Result<XxdServerInfo> _parse(int status, String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      return Err(
        ParseFailure('Chat server returned non-JSON (HTTP $status)', cause: e),
      );
    }
    if (json is! Map) {
      return Err(ParseFailure('Unexpected serverInfo reply (HTTP $status)'));
    }
    final info = XxdServerInfo.tryParse(Map<String, Object?>.from(json));
    if (info != null) return Ok(info);
    final message = json['message'];
    return Err(
      AuthFailure(
        message is String && message.isNotEmpty
            ? message
            : 'Chat login rejected (HTTP $status)',
      ),
    );
  }

  /// GETs [uri] (a `fileDownload` URL) through the pinned client.
  /// Downloads [uri]; [onProgress] gets the bytes received and the total
  /// (the response's length, else null).
  Future<Result<Uint8List>> download(
    Uri uri, {
    String? pinnedFingerprint,
    void Function(int received, int? total)? onProgress,
    Future<void>? cancel,
  }) async {
    XxdCertificate? rejected;
    final client = createPinnedHttpClient(
      pinnedFingerprint: pinnedFingerprint,
      onRejected: (cert) => rejected = cert,
    );
    // Closing the client aborts the transfer: the response stream then fails.
    var cancelled = false;
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        client.close(force: true);
      }),
    );
    try {
      final response = await (await client.getUrl(
        uri,
      )).close().timeout(const Duration(seconds: 60));
      final builder = BytesBuilder(copy: false);
      final total = response.contentLength > 0 ? response.contentLength : null;
      await response.forEach((chunk) {
        builder.add(chunk);
        onProgress?.call(builder.length, total);
      });
      if (cancelled) return const Err(CancelledFailure('Download cancelled'));
      if (response.statusCode != HttpStatus.ok) {
        return Err(
          response.statusCode == HttpStatus.notFound
              ? const NotFoundFailure('Attachment not found')
              : NetworkFailure(
                  'Attachment download failed (HTTP ${response.statusCode})',
                ),
        );
      }
      return Ok(builder.takeBytes());
    } on HandshakeException catch (e) {
      final cert = rejected;
      if (cert != null) return Err(untrustedCertificate(cert, e));
      return Err(NetworkFailure('TLS handshake with xxd failed', cause: e));
    } on Exception catch (e) {
      if (cancelled) {
        return Err(CancelledFailure('Download cancelled', cause: e));
      }
      return Err(NetworkFailure('Attachment download failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }

  /// Uploads a chat attachment: multipart POST `{server}/fileUpload` with the
  /// session token (as the 9.x client does). Returns the stored file's id and
  /// upload time (ms), which the message content must carry.
  Future<Result<({int id, int time})>> upload({
    required Uri server,
    required String token,
    required int userId,
    required String chatGid,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String serverName = '',
    String? pinnedFingerprint,
    void Function(double sent)? onProgress,
  }) async {
    XxdCertificate? rejected;
    final client = createPinnedHttpClient(
      pinnedFingerprint: pinnedFingerprint,
      onRejected: (cert) => rejected = cert,
    );
    final boundary = '----worknexus${DateTime.now().microsecondsSinceEpoch}';
    String field(String name, String value) =>
        '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n'
        '$value\r\n';
    final head = utf8.encode(
      '${field('userID', '$userId')}${field('gid', chatGid)}'
      '--$boundary\r\nContent-Disposition: form-data; name="file"; '
      'filename="${fileName.replaceAll('"', '_')}"\r\n'
      'Content-Type: ${mimeType ?? 'application/octet-stream'}\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    try {
      final request = await client.postUrl(server.resolve('/fileUpload'));
      request.headers
        ..set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        )
        ..set('ServerName', serverName)
        ..set('Authorization', token);
      final total = head.length + bytes.length + tail.length;
      request
        ..contentLength = total
        ..add(head);
      // Written in chunks and flushed, so [onProgress] follows what has
      // actually been handed to the socket.
      const chunk = 64 * 1024;
      for (var offset = 0; offset < bytes.length; offset += chunk) {
        final end = offset + chunk < bytes.length
            ? offset + chunk
            : bytes.length;
        request.add(Uint8List.sublistView(bytes, offset, end));
        await request.flush();
        onProgress?.call((head.length + end) / total);
      }
      request.add(tail);
      final response = await request.close().timeout(
        const Duration(minutes: 5),
      );
      final text = await response.transform(utf8.decoder).join();
      return _parseUpload(response.statusCode, text);
    } on HandshakeException catch (e) {
      final cert = rejected;
      if (cert != null) return Err(untrustedCertificate(cert, e));
      return Err(NetworkFailure('TLS handshake with xxd failed', cause: e));
    } on Exception catch (e) {
      return Err(NetworkFailure('Upload failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }

  Result<({int id, int time})> _parseUpload(int status, String text) {
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      json = null;
    }
    // The file record is either the reply itself or its `data`.
    final record = json is Map && json['data'] is Map ? json['data'] : json;
    if (record is Map) {
      final id = _int(record['id']);
      if (id != null && id > 0) {
        final time = _int(record['time']) ?? 0;
        return Ok((id: id, time: time < 100000000000 ? time * 1000 : time));
      }
    }
    final message = json is Map ? json['message'] : null;
    return Err(
      NetworkFailure(
        message is String && message.isNotEmpty
            ? message
            : 'Upload rejected (HTTP $status)',
      ),
    );
  }

  static int? _int(Object? v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  /// Signed `fileDownload` URL for a file attached to a message. [fileTime] is
  /// the file's `time` in milliseconds, as carried in the message content.
  Uri fileDownloadUri({
    required Uri server,
    required int userId,
    required String sessionId,
    required int fileId,
    required String fileName,
    required int fileTime,
    String serverName = '',
    bool thumbnail = false,
    bool preview = false,
  }) {
    final name = thumbnail ? 'thumb_$fileName' : fileName;
    return server
        .resolve('/fileDownload')
        .replace(
          queryParameters: {
            'fileName': name,
            'time': '${fileTime ~/ 1000}',
            'id': '$fileId',
            'gid': '$userId',
            if (serverName.isNotEmpty) 'ServerName': serverName,
            'sid': xxdFileSid(sessionId, name),
            if (preview) 'preview': '1',
          },
        );
  }
}

UntrustedCertificateFailure untrustedCertificate(
  XxdCertificate cert,
  Object cause,
) => UntrustedCertificateFailure(
  'The chat server certificate is not trusted',
  host: cert.host,
  fingerprint: cert.fingerprint,
  subject: cert.subject,
  issuer: cert.issuer,
  cause: cause,
);
