import 'dart:convert';
import 'dart:io';

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
