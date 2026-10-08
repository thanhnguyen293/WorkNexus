import 'dart:convert';

import '../value_objects/message_content.dart';

/// Turns xxd's (`contentType`, `content`) pair into a [MessageContent].
///
/// `plain` is literal text; `text` is Markdown (the official client's
/// "send as Markdown" option). Image/file/object contents are JSON; anything malformed or
/// unknown degrades to [UnsupportedContent] instead of failing the message.
class ParseMessageContent {
  const ParseMessageContent();

  /// A mention wrapped again in a link to the same user (the official
  /// client applied its mention markup twice):
  /// `[[@Name](@#40)-tail](@#40)`.
  static final _nested = RegExp(
    r'\[\[@([^\]]+)\]\(@#(\d+)\)[^\[\]]*\]\(@#\2\)',
  );

  static final _mention = RegExp(r'\[@([^\]]+)\]\(@#\d+\)');
  static final _nameStop = RegExp(r'[^A-Za-z0-9_]');

  /// Undoes two quirks of the official client's mention markup: a mention
  /// nested in another link to the same user (see [_nested]), and the rest
  /// of a typed name left after the mention — it links only the start up
  /// to the first symbol ("@Felix" of "@Felix-VN-Flutter"), giving
  /// `[@Felix-VN-Flutter](@#35)-VN-Flutter`.
  static String repairMentions(String text) {
    final unwrapped = text.replaceAllMapped(
      _nested,
      (m) => '[@${m[1]}](@#${m[2]})',
    );
    final out = StringBuffer();
    var at = 0;
    for (final m in _mention.allMatches(unwrapped)) {
      if (m.start < at) continue;
      out.write(unwrapped.substring(at, m.end));
      at = m.end;
      final name = m[1]!;
      final cut = name.indexOf(_nameStop);
      if (cut > 0 && unwrapped.startsWith(name.substring(cut), at)) {
        at += name.length - cut;
      }
    }
    out.write(unwrapped.substring(at));
    return out.toString();
  }

  MessageContent call(String contentType, String content) {
    switch (contentType) {
      case 'plain':
        return MessageContent.text(repairMentions(content));
      case 'text':
        return MessageContent.text(repairMentions(content), markdown: true);
      case 'image' || 'file':
        final json = _object(content);
        final inline = json?['content'];
        if (contentType == 'image' &&
            json?['type'] == 'base64' &&
            inline is String &&
            inline.isNotEmpty) {
          return MessageContent.image(
            fileId: 0,
            name: json?['name'] is String ? json!['name']! as String : '',
            size: _int(json?['size']) ?? 0,
            time: _int(json?['time']) ?? 0,
            width: _int(json?['width']),
            height: _int(json?['height']),
            inlineBase64: inline,
          );
        }
        final id = _int(json?['id']);
        final name = json?['name'];
        if (json == null || name is! String) break;
        if (id == null) {
          // A file still uploading (no server id yet): show it by name.
          return MessageContent.file(
            fileId: 0,
            name: name,
            size: _int(json['size']) ?? 0,
            time: 0,
          );
        }
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
                hasThumb: json['hasThumb'] == true,
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
