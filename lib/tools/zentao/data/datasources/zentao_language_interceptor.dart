import 'package:dio/dio.dart';

/// Asks ZenTao to answer in [lang] by sending its `lang` cookie on every
/// request to the server.
///
/// ZenTao picks a request's language from that cookie — a browser setting,
/// not the account's — and falls back to the server default (Chinese on many
/// installs) without it. ZenTao also writes a notification's text in the
/// language of the request that caused it, so a bug assigned from WorkNexus
/// left "Thanh指派了Bug" in everyone's notifications.
class ZenTaoLanguageInterceptor extends Interceptor {
  ZenTaoLanguageInterceptor({required this.host, this.lang = 'en'});

  /// The ZenTao server's host, read per request: the base URL can still
  /// change while an account is being added.
  final String Function() host;
  final String lang;

  // Compiled once: this runs on every request.
  static final _langCookie = RegExp(r'(^|;\s*)lang=');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.uri.host == host()) {
      final cookie = options.headers['Cookie']?.toString() ?? '';
      // A cookie of the same name set by a caller wins.
      if (!_langCookie.hasMatch(cookie)) {
        options.headers['Cookie'] = cookie.isEmpty
            ? 'lang=$lang'
            : '$cookie; lang=$lang';
      }
    }
    handler.next(options);
  }
}
