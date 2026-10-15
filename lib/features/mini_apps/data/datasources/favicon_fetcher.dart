import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import 'site_icon_source.dart';

/// Finds and downloads a web page's icon: the best `<link rel="…icon…">` the
/// page declares, then `/favicon.ico`. Talks to the site itself only. SVG icons
/// are skipped (Flutter does not draw them as images).
class FaviconFetcher implements SiteIconSource {
  FaviconFetcher([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              headers: const {'User-Agent': 'Mozilla/5.0 WorkNexus'},
            ),
          );

  final Dio _dio;
  static const _maxBytes = 1024 * 1024;

  @override
  Future<SiteIcon?> fetch(Uri page) async {
    final candidates = <Uri>[];
    var origin = page;
    try {
      final res = await _dio.getUri<String>(
        page,
        options: Options(responseType: ResponseType.plain),
      );
      origin = res.realUri;
      candidates.addAll(_declared(res.data ?? '', origin));
    } on DioException {
      // Fall through to /favicon.ico.
    }
    candidates.add(origin.replace(path: '/favicon.ico', query: ''));
    for (final uri in candidates.take(4)) {
      final icon = await _download(uri);
      if (icon != null) return icon;
    }
    return null;
  }

  /// The icons the page declares, best first: touch icons (large), then the
  /// largest sized icon, then the rest.
  List<Uri> _declared(String body, Uri base) {
    final scored = <(int, Uri)>[];
    for (final link in html.parse(body).querySelectorAll('link[rel]')) {
      final rel = (link.attributes['rel'] ?? '').toLowerCase();
      final href = link.attributes['href'];
      if (!rel.contains('icon') || href == null || href.isEmpty) continue;
      final uri = base.resolve(href);
      if (uri.path.toLowerCase().endsWith('.svg')) continue;
      final size = int.tryParse(
        (link.attributes['sizes'] ?? '').split('x').first,
      );
      final score =
          (rel.contains('apple-touch-icon') ? 1000 : 0) + (size ?? 16);
      scored.add((score, uri));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, uri) in scored) uri];
  }

  Future<SiteIcon?> _download(Uri uri) async {
    try {
      final res = await _dio.getUri<List<int>>(
        uri,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      final type = res.headers.value('content-type') ?? '';
      if (data == null || data.length < 64 || data.length > _maxBytes) {
        return null;
      }
      if (type.contains('text/') || type.contains('svg')) return null;
      return (
        bytes: Uint8List.fromList(data),
        extension: _extension(uri, type),
      );
    } on DioException {
      return null;
    }
  }

  String _extension(Uri uri, String contentType) {
    final path = uri.path.toLowerCase();
    for (final ext in const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico']) {
      if (path.endsWith('.$ext')) return ext;
    }
    if (contentType.contains('png')) return 'png';
    if (contentType.contains('jpeg')) return 'jpg';
    if (contentType.contains('webp')) return 'webp';
    return 'ico';
  }
}
