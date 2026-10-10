import 'dart:convert';

import '../value_objects/message_content.dart';
import 'decode_emoji.dart';

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
        return MessageContent.text(_text(content));
      case 'text':
        return MessageContent.text(_text(content), markdown: true);
      case 'image' || 'file':
        final json = _object(content);
        final inline = json?['content'];
        // The official client's large emoji: `{type: emoji, content: :smile:}`.
        if (contentType == 'image' &&
            json?['type'] == 'emoji' &&
            inline is String &&
            inline.isNotEmpty) {
          return _emoji(inline);
        }
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
            // Newer clients send a data URI (`data:image/png;base64,…`).
            inlineBase64: inline.startsWith('data:')
                ? inline.substring(inline.indexOf(',') + 1)
                : inline,
          );
        }
        final id = _int(json?['id']);
        final name = json?['name'];
        if (json == null || name is! String) break;
        final size = _int(json['size']);
        if (id == null) {
          // A file or image still uploading (no server id yet): show it by
          // name — an image at its real size, so the bubble keeps its shape
          // when the upload lands.
          if (size == null) break;
          return contentType == 'image'
              ? MessageContent.image(
                  fileId: 0,
                  name: name,
                  size: size,
                  time: 0,
                  width: _int(json['width']),
                  height: _int(json['height']),
                )
              : MessageContent.file(fileId: 0, name: name, size: size, time: 0);
        }
        final totalSize = size ?? 0;
        final time = _int(json['time']) ?? 0;
        final mime = json['type'] is String ? json['type'] as String : null;
        return contentType == 'image'
            ? MessageContent.image(
                fileId: id,
                name: name,
                size: totalSize,
                time: time,
                mimeType: mime,
                width: _int(json['width']),
                height: _int(json['height']),
                hasThumb: json['hasThumb'] == true,
              )
            : MessageContent.file(
                fileId: id,
                name: name,
                size: totalSize,
                time: time,
                mimeType: mime,
              );
      case 'emotion':
        // Newer official clients send a large emoji as its own content type,
        // with the same `{type: emoji, content: :smile:}` payload (or, from
        // some builds, just the shortname).
        final inline = _object(content)?['content'] ?? content.trim();
        if (inline is String && inline.isNotEmpty) {
          return _emoji(inline);
        }
      case 'notification':
        if (_object(content) case final json?) return _notification(json);
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

  static const _decodeEmoji = DecodeEmoji();

  static final _shortname = RegExp(r':[a-z0-9_+\-]+:');

  /// A large emoji — unless its shortname is one we cannot show, which then
  /// reads as ordinary text instead of a giant `:name:`.
  static MessageContent _emoji(String inline) {
    final emoji = _decodeEmoji(inline);
    return _shortname.hasMatch(emoji)
        ? MessageContent.text(emoji)
        : MessageContent.emoji(emoji);
  }

  static String _text(String content) => _decodeEmoji(repairMentions(content));

  /// The official client merges an `object` content's JSON into the
  /// notification before reading title, url and actions from it.
  static MessageContent _notification(Map<String, Object?> json) {
    final n = {...json};
    if (n['contentType'] == 'object' && n['content'] is String) {
      n.addAll(_object(n['content']! as String) ?? const {});
    }
    // ZenTao action cards ("X assigned 1 Bug") put the item as JSON in the
    // text itself, without saying it is an object: show the item, not the
    // raw JSON.
    final card = n['contentType'] != 'object' && n['content'] is String
        ? _zentaoCard(_object(n['content']! as String))
        : null;
    final actions = n['actions'];
    final sender = n['sender'];
    return MessageContent.notification(
      title: _str(n['title']),
      subtitle: _str(n['subtitle']) ?? card?.project,
      text: card != null
          ? card.text
          : n['content'] is String && n['contentType'] != 'object'
          ? _decodeEmoji(n['content']! as String)
          : '',
      markdown: card == null && n['contentType'] != 'plain',
      // The card's own link first: the outer one may be the official
      // client's `xxc:openInApp/…` wrapper.
      url: card?.url ?? _unwrapAppUrl(_str(n['url'])),
      actions: [
        for (final a in actions is List ? actions : [?actions])
          if (a is Map && _str(a['url']) != null)
            NotificationAction(
              label: _str(a['label']) ?? _str(a['url'])!,
              url: _str(a['url'])!,
            ),
      ],
      sender: switch (sender) {
        final Map<Object?, Object?> m =>
          _str(m['realname']) ?? _str(m['name']) ?? _str(m['displayName']),
        final String s when s.isNotEmpty => s,
        _ => null,
      },
    );
  }

  /// The item of a ZenTao action card (`objectType`, `objectName`, `id`,
  /// `cardURL`, `headSubTitle` = project); null when [json] is not one.
  static ({String text, String? url, String? project})? _zentaoCard(
    Map<String, Object?>? json,
  ) {
    if (json == null) return null;
    final name = _str(json['objectName']) ?? _str(json['name']);
    final url = _str(json['cardURL']);
    if (name == null && url == null) return null;
    final id = _str('${json['id'] ?? json['object'] ?? ''}');
    final count = _int(json['count']) ?? 1;
    return (
      text: [
        if (id != null) '#$id',
        ?name,
        // Only the first of several items is named.
        if (count > 1) '(+${count - 1})',
      ].join(' '),
      url: url,
      project: _str(json['headSubTitle']) ?? _str(json['headTitle']),
    );
  }

  /// `xxc:openInApp/<app>/<encoded url>` (the official client opening a
  /// page in its ZenTao tab) → the page's own url; others unchanged.
  static String? _unwrapAppUrl(String? url) {
    const prefix = 'xxc:openInApp/';
    if (url == null || !url.startsWith(prefix)) return url;
    final rest = url.substring(prefix.length);
    final slash = rest.indexOf('/');
    if (slash < 0) return url;
    try {
      final inner = Uri.decodeComponent(rest.substring(slash + 1));
      return inner.startsWith('http') ? inner : url;
    } on ArgumentError {
      return url;
    }
  }

  static String? _str(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

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
