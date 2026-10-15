import 'package:dio/dio.dart';

/// Injects the ZenTao `Token` header on v1 requests and transparently
/// re-authenticates once on a 401 (ZenTao tokens are ~24-min session ids).
///
/// The token endpoint (`/tokens`) is skipped so acquiring a token doesn't
/// recurse. Because the [Dio] uses `validateStatus: (s) => s < 500`, a 401 comes
/// back as a normal [Response] (not a [DioException]) — so the retry lives in
/// [onResponse], not [onError], mirroring the original hand-written logic.
class ZenTaoAuthInterceptor extends Interceptor {
  ZenTaoAuthInterceptor({
    required this.dio,
    required this.ensureToken,
    required this.reauthenticate,
  });

  final Dio dio;

  /// Returns a currently-valid token (authenticating on first use / expiry).
  final Future<String> Function() ensureToken;

  /// Forces a fresh token after a 401.
  final Future<String> Function() reauthenticate;

  static const _retriedFlag = 'zt_retried';

  bool _isAuthCall(RequestOptions o) => o.uri.path.endsWith('/tokens');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthCall(options)) return handler.next(options);
    try {
      options.headers['Token'] = await ensureToken();
    } catch (_) {
      // Proceed without a token; the resulting 401 is handled in onResponse.
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final req = response.requestOptions;
    if (response.statusCode == 401 &&
        !_isAuthCall(req) &&
        req.extra[_retriedFlag] != true) {
      try {
        req.headers['Token'] = await reauthenticate();
        req.extra[_retriedFlag] = true;
        final retried = await dio.fetch<dynamic>(req);
        return handler.resolve(retried);
      } catch (_) {
        // Fall through and surface the original 401 response.
      }
    }
    handler.next(response);
  }
}
