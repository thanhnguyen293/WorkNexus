import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/network/api_paging.dart';
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

  /// The signed-in user's profile (`GET /user`), plus the "my work" blocks
  /// named in [fields] (`?fields=task,bug,…`), each list capped at [limit]
  /// items. Kept as a raw map: the shape varies by block and server version,
  /// so callers parse it leniently.
  Future<Map<String, dynamic>> userInfo({String? fields, int? limit}) async {
    final res = await _dio.get<dynamic>(
      '$_v1/user',
      queryParameters: {'fields': ?fields, 'limit': ?limit},
    );
    if ((res.statusCode ?? 0) >= 400) {
      throw DioException.badResponse(
        statusCode: res.statusCode!,
        requestOptions: res.requestOptions,
        response: res,
      );
    }
    final json = _responseMap(res.data);
    // The bare profile is logged for inspecting it; the dashboard's blocks
    // would flood the log on every refresh.
    if (fields == null) {
      appTalker.info('ZenTao GET /user JSON: ${jsonEncode(json)}');
    }
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
    int recPerPage = kDefaultApiPageLimit,
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

  /// The user's web notifications (the bell menu), via the classic
  /// `message-ajaxGetDropmenu-all` page — REST v1 has no message endpoint. The
  /// reply's `data` is the page's view, carrying `allMessages` (by day).
  Future<Map<String, dynamic>> messages() async {
    final payload = _classicView(await _messageGet('ajaxGetDropmenu-all'));
    if (payload == null || !payload.containsKey('allMessages')) {
      throw DioException(
        requestOptions: RequestOptions(path: baseUrl),
        message: 'ZenTao messages reply had no message list',
      );
    }
    return payload;
  }

  /// Runs a classic message action, e.g. `ajaxMarkRead-all` or
  /// `ajaxDelete-12`. They answer with an empty body.
  Future<void> messageAction(String action) async {
    final res = await _messageGet(action);
    if (res.statusCode != 200) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        message: 'ZenTao message action failed',
      );
    }
  }

  Future<Response<dynamic>> _messageGet(String action) async {
    final token = await _ensureToken();
    return _dio.get<dynamic>(
      '$baseUrl/message-$action.json',
      queryParameters: {'zentaosid': token},
      options: Options(headers: {'Cookie': 'zentaosid=$token'}),
    );
  }

  /// The view map of a classic `{status, data}` reply, whose `data` is itself
  /// JSON-encoded; null when the reply is not that (e.g. a login page).
  Map<String, dynamic>? _classicView(Response<dynamic> res) {
    Object? body = res.data;
    for (var i = 0; i < 2 && body is String; i++) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    Object? data = body is Map ? (body['data'] ?? body) : null;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    return data is Map ? Map<String, dynamic>.from(data) : null;
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
  ) => classicPost(actionPath, {'uid': formUid(), ...form});

  /// POSTs [data] — a field map (form-urlencoded; list values are sent as
  /// repeated `key=` pairs, so name array fields `key[]`) or a [FormData]
  /// (multipart, for files) — to classic action [actionPath] (see
  /// [classicActionPost] for the session and CSRF headers).
  Future<Response<dynamic>> classicPost(String actionPath, Object data) async {
    final token = await _ensureToken();
    return _dio.post<dynamic>(
      '$baseUrl/$actionPath.json',
      queryParameters: {'zentaosid': token},
      data: data,
      options: Options(
        contentType: data is FormData
            ? Headers.multipartFormDataContentType
            : Headers.formUrlEncodedContentType,
        listFormat: ListFormat.multi,
        headers: _classicHeaders(token),
      ),
    );
  }

  /// GETs classic page [path] as JSON (`{base}/{path}.json`).
  Future<Response<dynamic>> classicGet(String path) async {
    final token = await _ensureToken();
    return _dio.get<dynamic>(
      '$baseUrl/$path.json',
      queryParameters: {'zentaosid': token},
      options: Options(headers: _classicHeaders(token)),
    );
  }

  Map<String, String> _classicHeaders(String token) => {
    'Cookie': 'zentaosid=$token',
    'Token': token,
    'Origin': Uri.parse(baseUrl).origin,
    'Referer': '$baseUrl/index.html',
    'X-Requested-With': 'XMLHttpRequest',
  };

  /// A ZenTao-style form uid (a `uniqid()`-like hex string) for classic actions.
  String formUid() => DateTime.now().microsecondsSinceEpoch.toRadixString(16);

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
