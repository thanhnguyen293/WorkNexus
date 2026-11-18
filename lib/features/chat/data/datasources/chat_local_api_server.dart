import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/chat_local_api.dart';

/// The localhost HTTP endpoint local tools (an AI assistant's MCP server)
/// use chat through, so they reuse this app's logged-in session instead of
/// holding the user's ZenTao password themselves.
///
/// Listens on 127.0.0.1 only, on a free port, and answers only requests that
/// carry the bearer token written — with the port — to [discoveryFileName] in
/// [directory]: a file only the user can read. Requests a browser makes (they
/// carry an `Origin`) are refused, so a web page cannot use it even if it
/// guessed the port. A new token is made at every start.
///
/// - `POST /v1/chat/send` `{accountId, chatGid, text, markdown?}` →
///   `{ok: true}`.
/// - `POST /v1/chat/load-older` `{accountId, chatGid, pageSize?}` →
///   `{ok: true, loaded, reachesStart}`: one more page of stored history.
/// - `POST /v1/chat/attachment` `{accountId, chatGid, messageId}` →
///   `{ok: true, path, name, size, mimeType, isImage}`: the message's file,
///   downloaded into this app's cache.
///
/// Errors are `{error}` with 400/401/403/404/413/502.
class ChatLocalApiServer {
  ChatLocalApiServer({required this.directory, Random? random})
    : _random = random ?? Random.secure();

  /// Where the discovery file goes: the app-support folder, beside the DB.
  final Future<Directory> Function() directory;
  final Random _random;

  static const discoveryFileName = 'chat_local_api.json';
  static const _maxBodyBytes = 64 * 1024;

  HttpServer? _server;
  File? _discovery;
  ChatLocalApiHandlers? _handlers;
  String _token = '';

  bool get isRunning => _server != null;

  /// Starts listening (or swaps [handlers] in when already listening).
  Future<void> start(ChatLocalApiHandlers handlers) async {
    _handlers = handlers;
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _token = base64Url.encode(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    try {
      _discovery = await _writeDiscovery(server.port);
    } on Object {
      await server.close(force: true);
      rethrow;
    }
    _server = server;
    server.listen((request) => unawaited(_serve(request)));
  }

  /// Stops listening and removes the discovery file.
  Future<void> stop() async {
    final server = _server;
    final file = _discovery;
    _server = null;
    _discovery = null;
    _handlers = null;
    await server?.close(force: true);
    if (file != null && await file.exists()) await file.delete();
  }

  Future<File> _writeDiscovery(int port) async {
    final dir = await directory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$discoveryFileName');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'version': 1, 'port': port, 'token': _token, 'pid': pid}),
      flush: true,
    );
    // Only the user may read the token. Windows keeps %APPDATA% per user.
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', temp.path]);
    }
    return temp.rename(file.path);
  }

  Future<void> _serve(HttpRequest request) async {
    final (status, body) = await _handle(request);
    final response = request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }

  Future<(int, Map<String, Object?>)> _handle(HttpRequest request) async {
    if (request.headers.value('origin') != null) {
      return (HttpStatus.forbidden, {'error': 'Browser requests are refused'});
    }
    if (!_authorized(request.headers.value(HttpHeaders.authorizationHeader))) {
      return (HttpStatus.unauthorized, {'error': 'Missing or wrong token'});
    }
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/v1/health') {
      return (HttpStatus.ok, {'ok': true});
    }
    if (request.method != 'POST' || !_routes.contains(path)) {
      return (HttpStatus.notFound, {'error': 'Unknown endpoint'});
    }
    final Object? json;
    try {
      final bytes = await _readBody(request);
      if (bytes == null) {
        return (
          HttpStatus.requestEntityTooLarge,
          {'error': 'Body over $_maxBodyBytes bytes'},
        );
      }
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return (HttpStatus.badRequest, {'error': 'Body is not UTF-8 JSON'});
    }
    if (json is! Map<String, Object?> ||
        json['accountId'] is! String ||
        json['chatGid'] is! String) {
      return (
        HttpStatus.badRequest,
        {'error': 'Expected accountId and chatGid strings'},
      );
    }
    final handlers = _handlers;
    if (handlers == null) {
      return (HttpStatus.serviceUnavailable, {'error': 'Stopping'});
    }
    final accountId = json['accountId']! as String;
    final chatGid = json['chatGid']! as String;
    switch (path) {
      case '/v1/chat/send':
        final text = json['text'];
        if (text is! String) {
          return (HttpStatus.badRequest, {'error': 'Expected a text string'});
        }
        return _reply(
          await handlers.send(
            accountId: accountId,
            chatGid: chatGid,
            text: text,
            markdown: json['markdown'] == true,
          ),
          (_) => {},
        );
      case '/v1/chat/load-older':
        final pageSize = json['pageSize'] ?? 100;
        if (pageSize is! int || pageSize < 1) {
          return (
            HttpStatus.badRequest,
            {'error': 'pageSize must be a positive integer'},
          );
        }
        return _reply(
          await handlers.loadOlder(
            accountId: accountId,
            chatGid: chatGid,
            pageSize: pageSize,
          ),
          (step) => {'loaded': step.loaded, 'reachesStart': step.reachesStart},
        );
      default:
        final messageId = json['messageId'];
        if (messageId is! int) {
          return (
            HttpStatus.badRequest,
            {'error': 'Expected a messageId integer'},
          );
        }
        return _reply(
          await handlers.attachment(
            accountId: accountId,
            chatGid: chatGid,
            messageId: messageId,
          ),
          (file) => {
            'path': file.path,
            'name': file.name,
            'size': file.size,
            'mimeType': file.mimeType,
            'isImage': file.isImage,
          },
        );
    }
  }

  static const _routes = {
    '/v1/chat/send',
    '/v1/chat/load-older',
    '/v1/chat/attachment',
  };

  static (int, Map<String, Object?>) _reply<T>(
    Result<T> result,
    Map<String, Object?> Function(T value) body,
  ) => switch (result) {
    Ok(:final value) => (HttpStatus.ok, {'ok': true, ...body(value)}),
    Err(failure: NotFoundFailure(:final message)) => (
      HttpStatus.notFound,
      {'error': message},
    ),
    Err(failure: ValidationFailure(:final message)) => (
      HttpStatus.badRequest,
      {'error': message},
    ),
    Err(:final failure) => (HttpStatus.badGateway, {'error': failure.message}),
  };

  /// Compares in constant time, so the token cannot be guessed byte by byte.
  bool _authorized(String? header) {
    const prefix = 'Bearer ';
    if (_token.isEmpty || header == null || !header.startsWith(prefix)) {
      return false;
    }
    final given = utf8.encode(header.substring(prefix.length));
    final expected = utf8.encode(_token);
    if (given.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < given.length; i++) {
      diff |= given[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// The body, or null when it is larger than [_maxBodyBytes]. An oversized
  /// body is still read to its end (and dropped): answering while it is
  /// unread makes Windows reset the connection, so the client never gets
  /// the 413.
  Future<List<int>?> _readBody(HttpRequest request) async {
    final out = BytesBuilder(copy: false);
    var tooLarge = false;
    await for (final chunk in request) {
      if (tooLarge) continue;
      out.add(chunk);
      if (out.length > _maxBodyBytes) {
        tooLarge = true;
        out.clear();
      }
    }
    return tooLarge ? null : out.takeBytes();
  }
}
