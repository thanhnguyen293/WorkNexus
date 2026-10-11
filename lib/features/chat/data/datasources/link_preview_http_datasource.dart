import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/link_preview.dart';
import 'link_preview_parser.dart';

/// Fetches link previews over HTTPS: YouTube via its oEmbed endpoint, any
/// other page by reading the start of its HTML for OpenGraph tags.
class LinkPreviewHttpDatasource {
  LinkPreviewHttpDatasource({HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  /// Only the head of a page is needed for its meta tags.
  static const _maxBytes = 512 * 1024;
  static const _timeout = Duration(seconds: 8);

  final HttpClient Function() _client;

  /// `Ok(null)` when the page has nothing worth showing (or is not a web
  /// page); `Err` when it could not be reached.
  Future<Result<LinkPreview?>> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return const Ok(null);
    }
    final client = _client()
      ..connectionTimeout = _timeout
      ..userAgent =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Safari/537.36 WorkNexus';
    try {
      if (_isYouTube(uri)) {
        final oembed = Uri.https('www.youtube.com', '/oembed', {
          'url': url,
          'format': 'json',
        });
        final body = await _read(client, oembed);
        return Ok(body == null ? null : parseOEmbed(body.text, url));
      }
      final page = await _read(client, uri, htmlOnly: true);
      return Ok(page == null ? null : parseLinkPreview(page.text, page.url));
    } on TimeoutException catch (e) {
      return Err(NetworkFailure('Link preview timed out', cause: e));
    } on Exception catch (e) {
      return Err(NetworkFailure('Link preview failed', cause: e));
    } finally {
      client.close(force: true);
    }
  }

  /// The decoded start of a successful response, with the final URL after
  /// redirects; null for errors and (with [htmlOnly]) non-HTML content.
  Future<({String text, Uri url})?> _read(
    HttpClient client,
    Uri uri, {
    bool htmlOnly = false,
  }) async {
    final request = await client.getUrl(uri).timeout(_timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'text/html,application/json');
    final response = await request.close().timeout(_timeout);
    final type = response.headers.contentType?.mimeType ?? '';
    if (response.statusCode != HttpStatus.ok ||
        (htmlOnly && !type.contains('html'))) {
      await response.drain<void>();
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(_timeout)) {
      bytes.addAll(chunk);
      if (bytes.length >= _maxBytes) break;
    }
    final finalUrl = response.redirects.isEmpty
        ? uri
        : uri.resolveUri(response.redirects.last.location);
    return (text: utf8.decode(bytes, allowMalformed: true), url: finalUrl);
  }

  static bool _isYouTube(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
  }
}
