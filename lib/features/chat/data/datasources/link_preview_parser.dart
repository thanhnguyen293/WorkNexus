import 'dart:convert';

import '../../domain/entities/link_preview.dart';

/// Reads OpenGraph / Twitter-card / `<title>` metadata from an HTML page.
/// Returns null when the page has no title.
LinkPreview? parseLinkPreview(String html, Uri pageUrl) {
  final meta = <String, String>{};
  for (final tag in RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final attrs = _attributes(tag[0]!);
    final key = (attrs['property'] ?? attrs['name'])?.toLowerCase();
    final content = attrs['content'];
    if (key == null || content == null || content.trim().isEmpty) continue;
    meta.putIfAbsent(key, () => _decodeEntities(content.trim()));
  }
  final titleTag = RegExp(
    r'<title[^>]*>([\s\S]*?)</title>',
    caseSensitive: false,
  ).firstMatch(html)?[1];
  final title =
      meta['og:title'] ??
      meta['twitter:title'] ??
      (titleTag == null ? null : _decodeEntities(titleTag.trim()));
  if (title == null || title.isEmpty) return null;
  final image = meta['og:image'] ?? meta['twitter:image'];
  return LinkPreview(
    url: pageUrl.toString(),
    siteName: meta['og:site_name'] ?? pageUrl.host,
    title: title,
    description:
        meta['og:description'] ??
        meta['twitter:description'] ??
        meta['description'],
    imageUrl: image == null ? null : pageUrl.resolve(image).toString(),
  );
}

/// A YouTube oEmbed reply as a preview.
LinkPreview? parseOEmbed(String json, String url) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (data is! Map || data['title'] is! String) return null;
  return LinkPreview(
    url: url,
    siteName: data['provider_name'] as String? ?? 'YouTube',
    title: data['title'] as String,
    description: data['author_name'] as String?,
    imageUrl: data['thumbnail_url'] as String?,
  );
}

Map<String, String> _attributes(String tag) => {
  for (final m in RegExp(
    r'''([a-zA-Z:_-]+)\s*=\s*("([^"]*)"|'([^']*)')''',
  ).allMatches(tag))
    m[1]!.toLowerCase(): m[3] ?? m[4] ?? '',
};

String _decodeEntities(String s) => s
    .replaceAllMapped(
      RegExp(r'&#(x?)([0-9a-fA-F]+);'),
      (m) =>
          String.fromCharCode(int.parse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16)),
    )
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&');
