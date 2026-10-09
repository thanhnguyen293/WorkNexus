import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../debug/app_talker.dart';
import '../api_paging.dart';
import 'zentao_api.dart';
import 'zentao_auth_interceptor.dart';
import 'zentao_models.dart';

part 'zentao_client_catalog.dart';
part 'zentao_client_classic.dart';

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
class ZenTaoClient extends _ZenTaoClientBase
    with _ZenTaoCatalogReads, _ZenTaoClassicChannel {
  ZenTaoClient({
    required super.baseUrl,
    required super.account,
    required super.password,
    super.dio,
  });

  /// Web roots to probe for [base], most likely first.
  static List<String> candidateBaseUrls(String base) =>
      _ZenTaoClientBase.candidateBaseUrls(base);
}

/// The configured [Dio] and the REST v1 session every part of [ZenTaoClient]
/// shares: base-URL detection, the shared token login, and JSON unwrapping.
abstract class _ZenTaoClientBase {
  _ZenTaoClientBase({
    required String baseUrl,
    required this.account,
    required this.password,
    Dio? dio,
  }) : _baseUrl = _normalizeBase(baseUrl),
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

  String _baseUrl;
  final String account;
  final String password;
  final Dio _dio;
  late ZenTaoApi _api;

  /// The ZenTao web root (e.g. `https://host/zentao`). May change once, via
  /// [detectBaseUrl], while an account is being added.
  String get baseUrl => _baseUrl;

  /// The type-safe REST v1 client (token + retry handled by the interceptor).
  ZenTaoApi get api => _api;

  String? _token;
  DateTime? _tokenExpiry;
  Future<String>? _authInFlight;

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

  /// Finds the web root that actually serves the REST v1 API and switches this
  /// client to it, returning the chosen root.
  ///
  /// ZenTao is installed either at the server root (Docker images) or under
  /// `/zentao` (ZBox / the default package), so users often enter just the
  /// host. We try the entered URL first, then `<url>/zentao`. A candidate counts
  /// as ZenTao when `POST /tokens` answers with JSON (even a 400 "bad login");
  /// a wrong root returns an HTML 404. If no candidate matches, the entered URL
  /// is kept so the regular login surfaces the real error.
  Future<String> detectBaseUrl() async {
    for (final candidate in candidateBaseUrls(_baseUrl)) {
      if (await _servesApi(candidate)) {
        if (candidate != _baseUrl) {
          _baseUrl = candidate;
          _api = ZenTaoApi(_dio, baseUrl: _v1);
          _token = null;
          _tokenExpiry = null;
        }
        break;
      }
    }
    return _baseUrl;
  }

  /// Web roots to probe for [base], most likely first.
  static List<String> candidateBaseUrls(String base) {
    final normalized = _normalizeBase(base);
    return [
      normalized,
      if (!normalized.endsWith('/zentao')) '$normalized/zentao',
    ];
  }

  Future<bool> _servesApi(String base) async {
    try {
      final res = await _dio.post<dynamic>(
        '$base/api.php/v1/tokens',
        data: const <String, String>{},
        options: Options(responseType: ResponseType.plain),
      );
      final type = res.headers.value(Headers.contentTypeHeader) ?? '';
      return res.statusCode != 404 && type.contains('json');
    } on DioException {
      return false;
    }
  }

  bool get _tokenValid =>
      _token != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Obtains (or refreshes) the v1 token. Returns the account on success.
  ///
  /// Concurrent callers share ONE in-flight `/tokens` request: ZenTao rotates the
  /// session id on every login and invalidates the previous one, so parallel
  /// logins (e.g. several inline images + attachments loading at once when a bug
  /// detail opens) would churn the token and make the first asset fetch 302 to
  /// the login page — the cause of images only appearing after a tab switch.
  Future<String> authenticate() {
    return _authInFlight ??= _login().whenComplete(() => _authInFlight = null);
  }

  Future<String> _login() async {
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

  /// Raw `GET /user` response for inspecting the signed-in user's profile.
  Future<Map<String, dynamic>> userInfo() async {
    final res = await _dio.get<dynamic>('$_v1/user');
    if ((res.statusCode ?? 0) >= 400) {
      throw DioException.badResponse(
        statusCode: res.statusCode!,
        requestOptions: res.requestOptions,
        response: res,
      );
    }
    final json = _responseMap(res.data);
    appTalker.info('ZenTao GET /user JSON: ${jsonEncode(json)}');
    return json;
  }

  Future<List<Map<String, dynamic>>> departments() async {
    final res = await _dio.get<dynamic>('$_v1/departments');
    if ((res.statusCode ?? 0) >= 400) {
      throw DioException.badResponse(
        statusCode: res.statusCode!,
        requestOptions: res.requestOptions,
        response: res,
      );
    }
    final data = res.data;
    final decoded = data is String ? jsonDecode(data) : data;
    final items = decoded is List
        ? decoded
        : decoded is Map
        ? decoded['departments']
        : null;
    if (items is! List) {
      throw const FormatException('ZenTao departments response is not a list');
    }
    return [
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Updates the signed-in user through ZenTao REST v1.
  Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> fields,
  ) async {
    final response = await _dio.put<dynamic>(
      '$_v1/users/$userId',
      data: fields,
      options: Options(contentType: Headers.jsonContentType),
    );
    if ((response.statusCode ?? 0) >= 400) {
      throw DioException.badResponse(
        statusCode: response.statusCode!,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
    final updated = _responseMap(response.data);
    if (updated['status'] == 'fail' || updated['result'] == 'fail') {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message:
            updated['message']?.toString() ?? 'ZenTao rejected profile update',
      );
    }
    return updated;
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
}
