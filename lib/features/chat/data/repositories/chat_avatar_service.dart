import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../datasources/xxd/xxd_backend.dart';
import '../datasources/xxd/xxd_http_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../datasources/xxd/xxd_server_info.dart';
import 'chat_session.dart';

/// Sends a request and stores its reply like a pushed packet.
typedef XxdRequestAndStore =
    Future<Result<void>> Function(ChatSession session, XxdRequest request);

/// Group pictures and the link to the user's ZenTao profile — both go
/// through ZenTao web (`im-authorize`) with a fresh `authToken`.
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
      final info = await _serverInfo(session);
      if (info case Err(:final failure)) return Err(failure);
      final uri = XxdBackend.authorizeUri(
        (info as Ok<XxdServerInfo>).value,
        session.connection.credentials.account,
        module: 'file',
        method: 'uploadChatAvatar',
      );
      if (uri == null) {
        return const Err(UnexpectedFailure('ZenTao web is not configured'));
      }
      final id = await _backend.uploadChatAvatar(
        uri,
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

  /// The user's ZenTao profile, opened signed in.
  Future<Result<Uri>> profileUri(ChatSession? session) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final info = await _serverInfo(session);
    if (info case Err(:final failure)) return Err(failure);
    final uri = XxdBackend.authorizeUri(
      (info as Ok<XxdServerInfo>).value,
      session.connection.credentials.account,
      module: 'my',
      method: 'profile',
    );
    return uri == null
        ? const Err(UnexpectedFailure('ZenTao web is not configured'))
        : Ok(uri);
  }

  /// `authToken` is short-lived: ask for a fresh one each time.
  Future<Result<XxdServerInfo>> _serverInfo(ChatSession session) =>
      _http.fetchServerInfo(session.connection.credentials);
}
