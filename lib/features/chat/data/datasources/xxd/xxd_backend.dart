import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../../core/debug/app_talker.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/result.dart';
import 'xxd_server_info.dart';
import 'xxd_signing.dart';
import 'xxd_tls.dart';

/// ZenTao web calls an xxd client makes as the signed-in user, through
/// `im-authorize` (ZenTao logs the request in with the server info's
/// `authToken`, then runs the wrapped action).
class XxdBackend {
  const XxdBackend();

  /// The `im-authorize` link running ZenTao [module]/[method] as [account]
  /// (port of the official client's URL builder).
  ///
  /// The token is not the server info's `authToken` itself but the key
  /// derived from it (see [xxdAuthorizeKey]); ZenTao answers "Invalid
  /// token." otherwise. [now] defaults to the server's clock in [info].
  static Uri? authorizeUri(
    XxdServerInfo info,
    String account, {
    required String module,
    required String method,
    Map<String, String> params = const {},
    DateTime? now,
  }) {
    final backend = info.backendUrl;
    final authToken = info.authToken;
    if (backend == null || authToken == null || authToken.isEmpty) {
      return null;
    }
    final token = xxdAuthorizeKey(
      account: account,
      authToken: authToken,
      serverNow: now ?? info.serverTime ?? DateTime.now(),
      window: info.authTokenWindow,
    );
    final base = backend.endsWith('/') ? backend : '$backend/';
    final pathInfo = info.requestType == 'PATH_INFO';
    // The wrapped action uses "_" so it survives as one PATH_INFO argument;
    // `im-authorize` turns them back into the request separator.
    final target = pathInfo
        ? '${[module, method, ...params.values].join('_')}.html'
        : 'index.php?m=$module&f=$method'
              '${params.entries.map((e) => '&${e.key}=${e.value}').join()}';
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
    final text = await _postImage(
      authorize,
      field: 'imgFile',
      image: image,
      pinnedFingerprint: pinnedFingerprint,
    );
    if (text case Err(:final failure)) return Err(failure);
    final reply = (text as Ok<String>).value;
    Object? json;
    try {
      json = jsonDecode(reply);
    } on FormatException {
      json = null;
    }
    final id = json is Map ? json['id'] : null;
    if (id == null || '$id'.isEmpty) {
      _logRejected('uploadChatAvatar', reply);
      return const Err(UnexpectedFailure('ZenTao did not accept the picture'));
    }
    return Ok('$id');
  }

  /// Uploads the user's own picture (PNG) through an [authorize] link to
  /// `my-uploadAvatar`; returns the stored file's id, which
  /// [cropUserAvatar] then makes the avatar.
  Future<Result<String>> uploadUserAvatar(
    Uri authorize,
    Uint8List png, {
    String? pinnedFingerprint,
  }) async {
    final text = await _postImage(
      authorize,
      // `user->uploadAvatar()` calls `file->saveUpload('avatar')`, whose
      // 'avatar' is the object type: the file itself is read from the
      // default field, `files`.
      field: 'files',
      image: png,
      pinnedFingerprint: pinnedFingerprint,
    );
    if (text case Err(:final failure)) return Err(failure);
    final reply = (text as Ok<String>).value;
    final id = userAvatarFileId(reply);
    if (id == null) {
      _logRejected('my-uploadAvatar', reply);
      return const Err(UnexpectedFailure('ZenTao did not accept the picture'));
    }
    return Ok(id);
  }

  /// The file id in a `my-uploadAvatar` reply: `fileID` where present,
  /// else the id in the `user-cropavatar` link it points at (a `callback`
  /// on ZenTao 18+, a `locate` before), in either request style.
  static String? userAvatarFileId(String reply) {
    try {
      final json = jsonDecode(reply);
      if (json is Map && json['result'] == 'fail') return null;
      final id = json is Map ? json['fileID'] : null;
      if (id != null && '$id'.isNotEmpty) return '$id';
    } on FormatException {
      // Not JSON: fall back to the link below.
    }
    return RegExp(
      r'cropavatar\D*?(\d+)',
      caseSensitive: false,
    ).firstMatch(reply)?.group(1);
  }

  /// Makes an uploaded picture the avatar through an [authorize] link to
  /// `user-cropAvatar`, keeping the whole [size]×[size] image (it is
  /// already cropped square).
  Future<Result<void>> cropUserAvatar(
    Uri authorize,
    int size, {
    String? pinnedFingerprint,
  }) async {
    final body = utf8.encode(
      Uri(
        queryParameters: {
          'left': '0',
          'top': '0',
          'right': '$size',
          'bottom': '$size',
          'width': '$size',
          'height': '$size',
          'originWidth': '$size',
          'originHeight': '$size',
          // The fields `user-cropAvatar` reads (`config->user->form`).
          'scaleWidth': '$size',
          'scaleHeight': '$size',
          'scaled': '0',
        },
      ).query,
    );
    final text = await _post(
      authorize,
      contentType: 'application/x-www-form-urlencoded',
      body: body,
      pinnedFingerprint: pinnedFingerprint,
    );
    if (text case Err(:final failure)) return Err(failure);
    final reply = (text as Ok<String>).value;
    Object? json;
    try {
      json = jsonDecode(reply);
    } on FormatException {
      json = null;
    }
    if (json is Map && json['result'] == 'success') return const Ok(null);
    _logRejected('user-cropAvatar', reply);
    return const Err(UnexpectedFailure('ZenTao did not save the picture'));
  }

  Future<Result<String>> _postImage(
    Uri uri, {
    required String field,
    required Uint8List image,
    String? pinnedFingerprint,
  }) {
    final boundary = '----worknexus${DateTime.now().microsecondsSinceEpoch}';
    final body = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="$field"; '
          'filename="avatar.png"\r\nContent-Type: image/png\r\n\r\n',
        ),
      )
      ..add(image)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    return _post(
      uri,
      contentType: 'multipart/form-data; boundary=$boundary',
      body: body.takeBytes(),
      pinnedFingerprint: pinnedFingerprint,
    );
  }

  /// POSTs [body] and returns the reply text. `im-authorize` signs the user
  /// in — setting the ZenTao session cookie — and answers with a 307 to the
  /// wrapped action. dart:io neither follows a POST's redirect nor keeps
  /// cookies, so both are done here: the body is re-sent (as 307/308
  /// require) with the cookies gathered so far, like the official client's
  /// `fetch(…, {credentials: 'include'})`.
  Future<Result<String>> _post(
    Uri uri, {
    required String contentType,
    required List<int> body,
    String? pinnedFingerprint,
  }) async {
    final client = createPinnedHttpClient(pinnedFingerprint: pinnedFingerprint);
    final cookies = <String, Cookie>{};
    try {
      var target = uri;
      for (var hop = 0; hop < 5; hop++) {
        final request = await client.postUrl(target);
        request.followRedirects = false;
        request.headers
          ..set(HttpHeaders.contentTypeHeader, contentType)
          ..set('X-Requested-With', 'XMLHttpRequest');
        request.cookies.addAll(cookies.values);
        request
          ..contentLength = body.length
          ..add(body);
        final response = await request.close().timeout(
          const Duration(minutes: 1),
        );
        for (final c in response.cookies) {
          cookies[c.name] = Cookie(c.name, c.value);
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        // Never the URL itself: it carries the sign-in key.
        appTalker.info(
          'Chat upload: hop $hop -> HTTP ${response.statusCode}'
          '${location == null ? '' : ' (redirect)'}'
          '${response.cookies.isEmpty ? '' : ', ${response.cookies.length} cookie(s)'}',
        );
        // `isRedirect` is false for a POST's 307, so check the code itself.
        final keepsBody =
            response.statusCode == HttpStatus.temporaryRedirect ||
            response.statusCode == HttpStatus.permanentRedirect;
        if (keepsBody && location != null) {
          await response.drain<void>();
          target = target.resolve(location);
          continue;
        }
        if (location != null) {
          // A 301/302/303 would turn the upload into a GET without the
          // picture; say so instead of failing silently.
          await response.drain<void>();
          appTalker.warning(
            'Chat upload: ZenTao redirected with HTTP ${response.statusCode} '
            'to ${Uri.tryParse(location)?.path ?? location}; the upload stops',
          );
          return const Err(
            UnexpectedFailure('ZenTao did not accept the picture'),
          );
        }
        return Ok(await response.transform(utf8.decoder).join());
      }
      return const Err(NetworkFailure('Too many redirects'));
    } on Exception catch (e, st) {
      appTalker.handle(e, st, 'Chat upload failed');
      return Err(NetworkFailure('Picture upload failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }

  /// Logs what ZenTao answered when it did not take a picture (the start of
  /// the reply: a login page, a JSON error, …).
  static void _logRejected(String action, String reply) {
    final text = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
    appTalker.warning(
      'Chat upload: $action rejected — '
      '${text.isEmpty ? '(empty reply)' : text.substring(0, text.length.clamp(0, 400))}',
    );
  }
}
