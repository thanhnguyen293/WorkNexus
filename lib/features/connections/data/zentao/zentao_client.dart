import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../core/debug/app_talker.dart';
import 'zentao_api.dart';
import 'zentao_auth_interceptor.dart';
import 'zentao_models.dart';

/// HTTP transport for ZenTao, handling both API generations:
///  - REST v1 (`/api.php/v1`) via the type-safe [ZenTaoApi] (retrofit). A
///    [ZenTaoAuthInterceptor] injects the `Token` header (a ~24-min PHP session
///    id) and re-auths once on 401.
///  - the legacy `index.php` / `{type}-view-{id}.json` channel for operations
///    with no REST v1 endpoint (comment posting, detail fallback, image bytes),
///    which stay hand-written below.
///
/// This is written to the researched contract; it is exercised live once a
/// connection is added in Settings.
class ZenTaoClient {
  ZenTaoClient({
    required String baseUrl,
    required this.account,
    required this.password,
    Dio? dio,
  }) : baseUrl = _normalizeBase(baseUrl),
       _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (s) => s != null && s < 500;
    // Self-hosted ZenTao often uses a self-signed / untrusted TLS cert on a
    // custom port. Accept it for the user's own server. (Only when we own the
    // Dio instance — tests inject their own adapter.)
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
    _api = ZenTaoApi(_dio, baseUrl: _v1);
    _dio.interceptors.add(buildTalkerDioLogger());
    _dio.interceptors.add(
      ZenTaoAuthInterceptor(
        dio: _dio,
        ensureToken: _ensureToken,
        reauthenticate: _reauthenticate,
      ),
    );
  }

  final String baseUrl;
  final String account;
  final String password;
  final Dio _dio;
  late final ZenTaoApi _api;

  /// The type-safe REST v1 client (token + retry handled by the interceptor).
  ZenTaoApi get api => _api;

  String? _token;
  DateTime? _tokenExpiry;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // If the user pasted the API base, keep the web root for classic actions.
    if (u.endsWith('/api.php/v1')) {
      u = u.substring(0, u.length - '/api.php/v1'.length);
    }
    return u;
  }

  String get _v1 => '$baseUrl/api.php/v1';

  bool get _tokenValid =>
      _token != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Obtains (or refreshes) the v1 token. Returns the account on success.
  Future<String> authenticate() async {
    final res = await _api.login({'account': account, 'password': password});
    final token = res.token;
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '$_v1/tokens'),
        message: 'ZenTao token request failed (no token in response)',
      );
    }
    _token = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 20));
    return account;
  }

  /// Current token, authenticating on first use / after expiry. Used by the
  /// auth interceptor (v1 requests) and the classic channels below.
  Future<String> _ensureToken() async {
    if (!_tokenValid) await authenticate();
    return _token!;
  }

  /// Forces a fresh token (used by the interceptor to recover from a 401).
  Future<String> _reauthenticate() async {
    await authenticate();
    return _token!;
  }

  /// Product list used by the ZenTao Sources tab.
  Future<ZenTaoProductsResponse> products({
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/products',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProductsResponse.fromJson(_responseMap(res.data));
  }

  /// Bugs for a product, used to sync all bugs regardless of assignee.
  Future<ZenTaoProductBugsResponse> productBugs(
    String productId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/products/$productId/bugs',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProductBugsResponse.fromJson(_responseMap(res.data));
  }

  Map<String, dynamic> _responseMap(Object? data) {
    Object? decoded = data;
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw DioException(
      requestOptions: RequestOptions(path: _v1),
      message: 'ZenTao response was not a JSON object',
    );
  }

  // ---- classic web-action channel (for operations with no REST v1 endpoint) ----

  /// POSTs to a classic ZenTao action, e.g. `action-comment-bug-4302`, at
  /// `{base}/{actionPath}.json?zentaosid={token}` with a form-urlencoded body.
  /// The authenticated v1 token doubles as the `zentaosid` session id.
  Future<Response<dynamic>> classicActionPost(
    String actionPath,
    Map<String, String> form,
  ) async {
    final token = await _ensureToken();
    return _dio.post<dynamic>(
      '$baseUrl/$actionPath.json',
      queryParameters: {'zentaosid': token},
      data: form,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': 'zentaosid=$token', 'Token': token},
      ),
    );
  }

  /// Fetches raw bytes for an (authenticated, self-signed-TLS) asset such as an
  /// inline image referenced by a ticket's rich text — e.g. ZenTao's
  /// `file-read-<id>.png`, which 302-redirects to the login page unless the
  /// session is presented. We attach the session id as a `zentaosid` cookie
  /// (ZenTao's session mechanism) plus the `Token` header and a query param for
  /// good measure, do NOT follow redirects, and only accept an image response
  /// (so a login-page HTML body is never mistaken for an image).
  Future<Uint8List?> fetchBytes(String url) async {
    final token = await _ensureToken();
    final base = Uri.parse('$baseUrl/');
    final resolved = base.resolveUri(Uri.parse(url));
    final onServer = resolved.host == base.host;
    final target = onServer
        ? resolved.replace(
            queryParameters: {...resolved.queryParameters, 'zentaosid': token},
          )
        : resolved;
    final res = await _dio.getUri<List<int>>(
      target,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 500,
        headers: onServer
            ? {'Cookie': 'zentaosid=$token', 'Token': token}
            : null,
      ),
    );
    final contentType = (res.headers.value('content-type') ?? '').toLowerCase();
    final data = res.data;
    if (res.statusCode == 200 &&
        data != null &&
        data.isNotEmpty &&
        contentType.startsWith('image')) {
      return Uint8List.fromList(data);
    }
    return null;
  }

  /// Classic detail JSON: `GET {base}/{type}-view-{id}.json`. Used as a fallback
  /// when the REST v1 detail endpoint returns an empty body (older installs /
  /// permission quirks). The payload is `{status, data}` where `data` (sometimes
  /// a JSON string) holds `{ <type>:{...}, actions:{...|[...]}, users:{...} }`.
  /// Returns the entity map with an embedded `actions` field, or null.
  Future<Map<String, dynamic>?> classicViewJson(String type, String id) async {
    final token = await _ensureToken();
    final res = await _dio.get<dynamic>(
      '$baseUrl/$type-view-$id.json',
      queryParameters: {'zentaosid': token},
    );
    Object? data = res.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    if (data is! Map) return null;
    final status = data['status']?.toString();
    if (status != null && status != 'success') return null;
    Object? payload = data['data'] ?? data;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        return null;
      }
    }
    if (payload is! Map) return null;
    final entity = payload[type];
    final result = entity is Map
        ? Map<String, dynamic>.from(entity)
        : <String, dynamic>{};
    if (result['actions'] == null && payload['actions'] != null) {
      result['actions'] = payload['actions'];
    }
    return result.isEmpty ? null : result;
  }
}
