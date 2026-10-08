import 'dart:convert';

import '../value_objects/message_content.dart';

/// Turns xxd's (`contentType`, `content`) pair into a [MessageContent].
///
/// Text arrives as `plain` from the 9.x client but as `text` from others, so
/// both are text. Image/file/object contents are JSON; anything malformed or
/// unknown degrades to [UnsupportedContent] instead of failing the message.
class ParseMessageContent {
  const ParseMessageContent();

  MessageContent call(String contentType, String content) {
    switch (contentType) {
      case 'plain' || 'text':
        return MessageContent.text(content);
      case 'image' || 'file':
        final json = _object(content);
        final id = _int(json?['id']);
        final name = json?['name'];
        if (json == null || id == null || name is! String) break;
        final size = _int(json['size']) ?? 0;
        final time = _int(json['time']) ?? 0;
        final mime = json['type'] is String ? json['type'] as String : null;
        return contentType == 'image'
            ? MessageContent.image(
                fileId: id,
                name: name,
                size: size,
                time: time,
                mimeType: mime,
                width: _int(json['width']),
                height: _int(json['height']),
              )
            : MessageContent.file(
                fileId: id,
                name: name,
                size: size,
                time: time,
                mimeType: mime,
              );
      case 'object':
        final json = _object(content);
        final url = json?['url'];
        if (json?['type'] == 'url' && url is String && url.isNotEmpty) {
          final title = json?['title'];
          return MessageContent.link(
            url: url,
            title: title is String && title.isNotEmpty ? title : null,
          );
        }
    }
    return MessageContent.unsupported(contentType);
  }

  static Map<String, Object?>? _object(String content) {
    try {
      final json = jsonDecode(content);
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  static int? _int(Object? v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
}
