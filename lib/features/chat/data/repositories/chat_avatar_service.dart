import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../datasources/square_avatar_png.dart';
import '../datasources/xxd/xxd_backend.dart';
import '../datasources/xxd/xxd_http_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../datasources/xxd/xxd_server_info.dart';
import 'chat_session.dart';

/// Sends a request and stores its reply like a pushed packet.
typedef XxdRequestAndStore = Future<Result<void>> Function(
  ChatSession session,
  XxdRequest request,
);

/// Group pictures and the user's own picture — both go through ZenTao web
/// (`im-authorize`) with a fresh `authToken`.
class ChatAvatarService {
  ChatAvatarService(this._http, {XxdBackend backend = const XxdBackend()})
    : _backend = backend;

  final XxdHttpDatasource _http;
  final XxdBackend _backend;

  /// A group's avatar: an uploaded [image], or [text] on [color] (`#RRGGBB`).
  Future<Result<void>> setGroupAvatar(
    ChatSession? session,
    String chatGid, {
    required XxdRequestAndStore send,
    String? text,
    String? color,
    Uint8List? image,
  }) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final Map<String, Object?> avatar;
    if (image != null) {
      final uri = await _authorize(
        session,
        module: 'file',
        method: 'uploadChatAvatar',
      );
      if (uri case Err(:final failure)) return Err(failure);
      final id = await _backend.uploadChatAvatar(
        (uri as Ok<Uri>).value,
        image,
        pinnedFingerprint: session.connection.credentials.pinnedFingerprint,
      );
      if (id case Err(:final failure)) return Err(failure);
      avatar = {
        'type': 'image',
        'data': {'imgId': (id as Ok<String>).value},
      };
    } else {
      avatar = {
        'type': 'text',
        'data': {'bgColor': color ?? '', 'customText': text ?? ''},
      };
    }
    return send(
      session,
      XxdRequest('chatsetavatar', params: [chatGid, avatar]),
    );
  }

  /// The signed-in user's own picture: [image] cut square, uploaded to
  /// ZenTao (`my-uploadAvatar`) and made the avatar (`user-cropAvatar`) —
  /// the steps ZenTao web's profile runs, as xxd has no call for it.
  Future<Result<void>> setMyAvatar(
    ChatSession? session,
    Uint8List image,
  ) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final square = await squareAvatarPng(image);
    if (square case Err(:final failure)) return Err(failure);
    final (:png, :side) = (square as Ok<({Uint8List png, int side})>).value;
    final credentials = session.connection.credentials;

    final upload = await _authorize(
      session,
      module: 'my',
      method: 'uploadAvatar',
    );
    if (upload case Err(:final failure)) return Err(failure);
    final fileId = await _backend.uploadUserAvatar(
      (upload as Ok<Uri>).value,
      png,
      pinnedFingerprint: credentials.pinnedFingerprint,
    );
    if (fileId case Err(:final failure)) return Err(failure);

    // A fresh token for the second call, as for every `im-authorize`.
    final crop = await _authorize(
      session,
      module: 'user',
      method: 'cropAvatar',
      params: {'imageID': (fileId as Ok<String>).value},
    );
    if (crop case Err(:final failure)) return Err(failure);
    return _backend.cropUserAvatar(
      (crop as Ok<Uri>).value,
      side,
      pinnedFingerprint: credentials.pinnedFingerprint,
    );
  }

  Future<Result<Uri>> _authorize(
    ChatSession session, {
    required String module,
    required String method,
    Map<String, String> params = const {},
  }) async {
    final info = await _serverInfo(session);
    if (info case Err(:final failure)) return Err(failure);
    final uri = XxdBackend.authorizeUri(
      (info as Ok<XxdServerInfo>).value,
      session.connection.credentials.account,
      module: module,
      method: method,
      params: params,
    );
    return uri == null
        ? const Err(UnexpectedFailure('ZenTao web is not configured'))
        : Ok(uri);
  }

  /// `authToken` is short-lived: ask for a fresh one each time.
  Future<Result<XxdServerInfo>> _serverInfo(ChatSession session) =>
      _http.fetchServerInfo(session.connection.credentials);
}
