import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import 'xxd_server_info.dart';
import 'xxd_tls.dart';

/// ZenTao web calls an xxd client makes as the signed-in user, through
/// `im-authorize` (ZenTao logs the request in with the server info's
/// `authToken`, then runs the wrapped action).
class XxdBackend {
  const XxdBackend();

  /// The `im-authorize` link running ZenTao [module]/[method] as [account]
  /// (port of the official client's URL builder).
  static Uri? authorizeUri(
    XxdServerInfo info,
    String account, {
    required String module,
    required String method,
  }) {
    final backend = info.backendUrl;
    final token = info.authToken;
    if (backend == null || token == null) return null;
    final base = backend.endsWith('/') ? backend : '$backend/';
    final pathInfo = info.requestType == 'PATH_INFO';
    // The wrapped action uses "_" so it survives as one PATH_INFO argument.
    final target = pathInfo
        ? '${module}_$method.html'
        : 'index.php?m=$module&f=$method';
    final args = {
      'account': account,
      'token': token,
      'device': 'desktop',
      'url': target,
    };
    final fix = info.requestFix;
    return Uri.parse(
      pathInfo
          ? '${base}im${fix}authorize$fix'
                '${args.values.map(Uri.encodeComponent).join(fix)}.html'
          : '${base}index.php?m=im&f=authorize'
                '${args.entries.map((e) => '&${e.key}=${Uri.encodeComponent(e.value)}').join()}',
    );
  }

  /// Uploads a group picture (PNG/JPEG) through [authorize]; returns the
  /// image id `chatsetavatar` takes.
  Future<Result<String>> uploadChatAvatar(
    Uri authorize,
    Uint8List image, {
    String? pinnedFingerprint,
  }) async {
    final client = createPinnedHttpClient(pinnedFingerprint: pinnedFingerprint);
    final boundary = '----worknexus${DateTime.now().microsecondsSinceEpoch}';
    final head = utf8.encode(
      '--$boundary\r\nContent-Disposition: form-data; name="imgFile"; '
      'filename="avatar.png"\r\nContent-Type: image/png\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    try {
      final request = await client.postUrl(authorize);
      request.headers
        ..set(
          HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary',
        )
        ..set('X-Requested-With', 'XMLHttpRequest');
      request
        ..contentLength = head.length + image.length + tail.length
        ..add(head)
        ..add(image)
        ..add(tail);
      final response = await request.close().timeout(
        const Duration(minutes: 1),
      );
      final text = await response.transform(utf8.decoder).join();
      final Object? json;
      try {
        json = jsonDecode(text);
      } on FormatException {
        return const Err(
          UnexpectedFailure('ZenTao did not accept the picture'),
        );
      }
      final id = json is Map ? json['id'] : null;
      return id == null || '$id'.isEmpty
          ? const Err(UnexpectedFailure('ZenTao did not accept the picture'))
          : Ok('$id');
    } on Exception catch (e) {
      return Err(NetworkFailure('Picture upload failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }
}
