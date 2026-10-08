import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/value_objects/message_content.dart';
import '../datasources/image_header_size.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_http_datasource.dart';
import 'chat_session.dart';

/// Downloads message attachments through the pinned xxd HTTPS client and
/// keeps recent ones in a byte-bounded in-memory LRU.
class ChatAttachmentLoader {
  ChatAttachmentLoader(this._http, {this.maxCacheBytes = 64 * 1024 * 1024});

  final XxdHttpDatasource _http;
  final int maxCacheBytes;
  // Insertion-ordered map: re-inserting on a hit makes it an LRU.
  final _cache = <String, Uint8List>{};
  int _cachedBytes = 0;

  Future<Result<Uint8List>> load(
    ChatSession? session,
    MessageContent content, {
    bool thumbnail = false,
  }) async {
    if (content case ImageContent(:final inlineBase64?)) {
      try {
        return Ok(base64Decode(inlineBase64));
      } on FormatException catch (e) {
        return Err(ParseFailure('Broken inline image', cause: e));
      }
    }
    final (fileId, name, time) = switch (content) {
      ImageContent(:final fileId, :final name, :final time) ||
      FileContent(
        :final fileId,
        :final name,
        :final time,
      ) => (fileId, name, time),
      _ => (null, null, null),
    };
    if (fileId == null || name == null || time == null) {
      return const Err(NotFoundFailure('This message has no attachment'));
    }
    final state = session?.connection.state;
    final xxd = state is XxdOnline ? state.session : null;
    final sessionId = xxd?.sessionId;
    // Only images the server made a preview for have a `thumb_` file.
    final thumb = thumbnail && content is ImageContent && content.hasThumb;
    final key =
        '${session?.connection.credentials.server}#$fileId${thumb ? '#thumb' : ''}';
    final cached = _cache.remove(key);
    if (cached != null) return Ok(_cache[key] = cached);
    if (session == null || xxd == null || sessionId == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    final credentials = session.connection.credentials;
    final result = await _http.download(
      _http.fileDownloadUri(
        server: credentials.server,
        userId: xxd.userId,
        sessionId: sessionId,
        fileId: fileId,
        fileName: name,
        fileTime: time,
        serverName: credentials.serverName,
        thumbnail: thumb,
      ),
      pinnedFingerprint: credentials.pinnedFingerprint,
    );
    if (result case Ok(:final value)) _remember(key, value);
    return result;
  }

  /// The attachment as a local file (downloaded once into [cacheDir]), for
  /// players and "open with" — which cannot use the pinned HTTPS client.
  Future<Result<String>> localFile(
    ChatSession? session,
    MessageContent content,
    Directory cacheDir,
  ) async {
    final (fileId, name) = switch (content) {
      ImageContent(:final fileId, :final name) ||
      FileContent(:final fileId, :final name) => (fileId, name),
      _ => (0, ''),
    };
    final safeName = name.replaceAll(RegExp(r'[/\\:]'), '_');
    final file = File('${cacheDir.path}/${fileId}_$safeName');
    if (fileId > 0 && await file.exists() && await file.length() > 0) {
      return Ok(file.path);
    }
    final bytes = await load(session, content);
    switch (bytes) {
      case Ok(:final value):
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(value, flush: true);
          return Ok(file.path);
        } on FileSystemException catch (e) {
          return Err(StorageFailure('Could not save the attachment', cause: e));
        }
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Uploads [bytes] for chat [chatGid]; returns the message `contentType`
  /// and `content` (JSON) that point at the stored file.
  Future<Result<({String contentType, String content})>> upload(
    ChatSession? session, {
    required String chatGid,
    required String name,
    required Uint8List bytes,
    String? mimeType,
    void Function(double sent)? onProgress,
  }) async {
    final state = session?.connection.state;
    final xxd = state is XxdOnline ? state.session : null;
    if (session == null || xxd == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    final limit = xxd.uploadFileSize;
    if (limit != null && limit > 0 && bytes.length > limit) {
      return Err(
        UnexpectedFailure(
          'File is larger than the server allows '
          '(${limit ~/ (1024 * 1024)} MB)',
        ),
      );
    }
    final credentials = session.connection.credentials;
    final uploaded = await _http.upload(
      server: credentials.server,
      token: xxd.token,
      userId: xxd.userId,
      chatGid: chatGid,
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
      serverName: credentials.serverName,
      pinnedFingerprint: credentials.pinnedFingerprint,
      onProgress: onProgress,
    );
    switch (uploaded) {
      case Ok(:final value):
        _remember('${credentials.server}#${value.id}', bytes);
        return Ok((
          contentType: isImageMime(mimeType) ? 'image' : 'file',
          content: jsonEncode({
            'name': name,
            'size': bytes.length,
            'send': true,
            'type': ?mimeType,
            'id': value.id,
            'time': value.time,
            // Lets every client reserve the image's space before it loads.
            if (isImageMime(mimeType)) ...?_dimensions(bytes),
          }),
        ));
      case Err(:final failure):
        return Err(failure);
    }
  }

  void _remember(String key, Uint8List bytes) {
    if (bytes.length > maxCacheBytes) return;
    _cache[key] = bytes;
    _cachedBytes += bytes.length;
    while (_cachedBytes > maxCacheBytes && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _cachedBytes -= _cache.remove(oldest)!.length;
    }
  }
}

/// Images get an image message (rendered inline); everything else a file.
bool isImageMime(String? mimeType) =>
    mimeType != null &&
    mimeType.startsWith('image/') &&
    mimeType != 'image/svg+xml';

/// MIME type from a file name's extension, for attachments whose source gave
/// none (pasted file paths, picked files).
String? mimeTypeForFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return const {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  }[name.substring(dot + 1).toLowerCase()];
}

Map<String, int>? _dimensions(Uint8List bytes) {
  final size = imageHeaderSize(bytes);
  return size == null ? null : {'width': size.width, 'height': size.height};
}
