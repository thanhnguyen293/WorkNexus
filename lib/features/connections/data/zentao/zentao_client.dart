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

  /// All bugs for a product via REST v1 `GET /products/{id}/bugs`. This endpoint
  /// does **not** honor ZenTao's `browseType` tab views (it ignores the param and
  /// always returns every bug) — use [classicProductBugs] for the tab slices.
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

  /// Bugs for a product via the **classic** `bug-browse-…json` action, which —
  /// unlike REST v1 — honors ZenTao's [browseType] tab views (`all` / `unclosed`
  /// / `openedbyme` / `assigntome` / `resolvedbyme` / `assignedbyme`). URL:
  /// `{base}/bug-browse-{productID}-0-{browseType}-0-id_desc-0-{recPerPage}-{pageID}.json`.
  /// The response is the classic `{status, data}` envelope (data is sometimes a
  /// JSON string) whose payload carries `bugs` (a list or an id-keyed map) and a
  /// `pager` with `recTotal`. Parsed leniently; the exact shape is validated live
  /// (capture from the Talker panel, like `products_json.txt`).
  Future<ZenTaoProductBugsResponse> classicProductBugs(
    String productId, {
    required String browseType,
    int recPerPage = 100,
    int pageID = 1,
  }) async {
    final token = await _ensureToken();
    final path =
        'bug-browse-$productId-0-$browseType-0-id_desc-0-$recPerPage-$pageID';
    final res = await _dio.get<dynamic>(
      '$baseUrl/$path.json',
      queryParameters: {'zentaosid': token},
    );
    Object? data = res.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return const ZenTaoProductBugsResponse(total: 0, bugs: []);
      }
    }
    Object? payload = data is Map ? (data['data'] ?? data) : null;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        payload = null;
      }
    }
    if (payload is! Map) {
      return const ZenTaoProductBugsResponse(total: 0, bugs: []);
    }
    final rawBugs = payload['bugs'];
    final bugs = <ZenTaoEntity>[];
    if (rawBugs is List) {
      for (final b in rawBugs) {
        if (b is Map) {
          bugs.add(ZenTaoEntity.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    } else if (rawBugs is Map) {
      for (final b in rawBugs.values) {
        if (b is Map) {
          bugs.add(ZenTaoEntity.fromJson(Map<String, dynamic>.from(b)));
        }
      }
    }
    final pager = payload['pager'];
    final total = pager is Map
        ? (zentaoInt(pager['recTotal']) ?? bugs.length)
        : bugs.length;
    return ZenTaoProductBugsResponse(total: total, bugs: bugs);
  }

  /// Projects for this account (`GET /projects`), used to group executions.
  Future<ZenTaoProjectsResponse> projects({
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/projects',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoProjectsResponse.fromJson(_responseMap(res.data));
  }

  /// Executions of a project (`GET /projects/{id}/executions`).
  Future<ZenTaoExecutionsResponse> projectExecutions(
    String projectId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/projects/$projectId/executions',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoExecutionsResponse.fromJson(_responseMap(res.data));
  }

  /// Tasks of an execution (`GET /executions/{id}/tasks`), used to sync all
  /// tasks regardless of assignee.
  Future<ZenTaoExecutionTasksResponse> executionTasks(
    String executionId, {
    required int page,
    required int limit,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_v1/executions/$executionId/tasks',
      queryParameters: {'page': page, 'limit': limit},
    );
    return ZenTaoExecutionTasksResponse.fromJson(_responseMap(res.data));
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
  ///
  /// ZenTao guards state-changing POSTs with a CSRF check that requires the
  /// `Origin`/`Referer` host to match the site — GET reads (the board browse)
  /// are exempt, which is why reads worked while every write silently bounced
  /// to the login page. We present the site as origin (as the web client does)
  /// and include a form [uid] (namespaces any inline uploads; the web always
  /// sends one) so the action is accepted.
  Future<Response<dynamic>> classicActionPost(
    String actionPath,
    Map<String, String> form,
  ) async {
    final token = await _ensureToken();
    return _dio.post<dynamic>(
      '$baseUrl/$actionPath.json',
      queryParameters: {'zentaosid': token},
      data: {'uid': _formUid(), ...form},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Cookie': 'zentaosid=$token',
          'Token': token,
          'Origin': Uri.parse(baseUrl).origin,
          'Referer': '$baseUrl/index.html',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
  }

  /// A ZenTao-style form uid (a `uniqid()`-like hex string) for classic actions.
  String _formUid() => DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  /// Fetches raw bytes for an (authenticated, self-signed-TLS) asset such as an
  /// inline image referenced by a ticket's rich text — e.g. ZenTao's
  /// `file-read-<id>.png`, which 302-redirects to the login page unless the
  /// session is presented. Only an image response is accepted (so a login-page
  /// HTML body is never mistaken for an image). See [_authedBytes] for the
  /// session handling and the failure-recovery retries.
  Future<Uint8List?> fetchBytes(String url) =>
      _authedBytes(url, imageOnly: true);

  /// Downloads an attachment's raw bytes through the authenticated session,
  /// accepting any content type (unlike [fetchBytes], which is image-only). Used
  /// by the detail panel's attachment "open" action. Returns null on failure.
  Future<Uint8List?> downloadBytes(String url) =>
      _authedBytes(url, imageOnly: false);

  /// Shared transport for [fetchBytes]/[downloadBytes]: attaches the session id
  /// as a `zentaosid` cookie (ZenTao's session mechanism) plus the `Token`
  /// header and a query param for good measure, and does NOT follow redirects.
  ///
  /// Unlike the v1 channel — where the auth interceptor heals a dead session by
  /// re-authenticating on a 401 — the classic asset channel signals a session
  /// problem as a **302 to the login page**, which used to be a dead end: the
  /// bytes silently came back null and inline images stayed broken until the
  /// detail tab was rebuilt (the "first open shows broken images" bug). So a
  /// failed on-server fetch now recovers in two steps mirroring the
  /// interceptor's retry: once more on the SAME session (right after login,
  /// ZenTao can bounce the classic channel's first hit while the freshly minted
  /// v1 token warms up server-side), then once on a FRESH login (session truly
  /// invalidated). Off-server URLs carry no session, so they get no retry.
  Future<Uint8List?> _authedBytes(String url, {required bool imageOnly}) async {
    final base = Uri.parse('$baseUrl/');
    final resolved = base.resolveUri(Uri.parse(url));
    final onServer = resolved.host == base.host;

    Future<Uint8List?> attempt(String token) async {
      final target = onServer
          ? resolved.replace(
              queryParameters: {
                ...resolved.queryParameters,
                'zentaosid': token,
              },
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
      final contentType = (res.headers.value('content-type') ?? '')
          .toLowerCase();
      final data = res.data;
      if (res.statusCode == 200 &&
          data != null &&
          data.isNotEmpty &&
          (!imageOnly || contentType.startsWith('image'))) {
        return Uint8List.fromList(data);
      }
      return null;
    }

    final token = await _ensureToken();
    var bytes = await attempt(token);
    if (bytes == null && onServer) {
      // Same session, second chance (classic-channel warm-up after login).
      bytes = await attempt(token);
    }
    if (bytes == null && onServer) {
      // Session presumed dead — force a fresh login (concurrent recoveries
      // share the one in-flight /tokens request) and try once more.
      await authenticate();
      bytes = await attempt(await _ensureToken());
    }
    return bytes;
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
