part of 'zentao_client.dart';

/// The classic `index.php` channel for operations with no REST v1 endpoint:
/// web-action POSTs, authenticated image / attachment bytes, and the detail
/// JSON fallback.
mixin _ZenTaoClassicChannel on _ZenTaoClientBase {
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
  ///
  /// Only a response that looks like a session problem — a redirect, 401/403,
  /// or an HTML page (the login form) — is retried. Anything else (404, a
  /// non-image file where an image was asked for) fails at once: retrying it
  /// can't help, and the forced re-login would rotate the session under every
  /// other request in flight.
  Future<Uint8List?> _authedBytes(String url, {required bool imageOnly}) async {
    final base = Uri.parse('$baseUrl/');
    final resolved = base.resolveUri(Uri.parse(url));
    final onServer = resolved.host == base.host;
    var sessionSuspect = false;

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
      final status = res.statusCode ?? 0;
      sessionSuspect =
          (status >= 300 && status < 400) ||
          status == 401 ||
          status == 403 ||
          (status == 200 && contentType.startsWith('text/html'));
      return null;
    }

    final token = await _ensureToken();
    var bytes = await attempt(token);
    if (bytes == null && onServer && sessionSuspect) {
      // Same session, second chance (classic-channel warm-up after login).
      bytes = await attempt(token);
    }
    if (bytes == null && onServer && sessionSuspect) {
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
