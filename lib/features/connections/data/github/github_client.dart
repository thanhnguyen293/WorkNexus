import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../core/debug/app_talker.dart';
import 'github_models.dart';

/// HTTP transport for the GitHub REST API, bound to one account's base URL +
/// Personal Access Token (PAT). The PAT is attached as an `Authorization: Bearer`
/// header (with the `Accept` + API-version headers) by an interceptor — but only
/// for requests to the API host, so it is never leaked to a third-party host
/// (e.g. an external image URL).
///
/// Base URL handling differs from GitLab: on github.com the API lives on a
/// separate host (`https://api.github.com`), while GitHub Enterprise Server uses
/// `https://<host>/api/v3`. List endpoints return a bare JSON array and the
/// Search API wraps results in `{ items: [...] }`; both paginate through the
/// RFC-5988 `Link` response header (`rel="next"`). `validateStatus` is left at
/// dio's default (throw on non-2xx) so the adapter's `_guard` classifies 401/404.
class GitHubClient {
  factory GitHubClient({
    required String baseUrl,
    required String token,
    Dio? dio,
  }) {
    final r = _resolve(baseUrl);
    return GitHubClient._(
      apiBase: r.apiBase,
      apiHost: r.host,
      webBase: r.webBase,
      token: token,
      dio: dio,
    );
  }

  GitHubClient._({
    required String apiBase,
    required String apiHost,
    required this.webBase,
    required this.token,
    Dio? dio,
  }) : _apiHost = apiHost,
       _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = apiBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30);
    // GitHub Enterprise Server may use a self-signed / untrusted TLS cert. Accept
    // it for the user's own server, but keep normal validation for github.com /
    // api.github.com so a bad cert there is never silently trusted. Only when we
    // own the Dio instance (tests inject their own adapter).
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) =>
              host != 'github.com' && host != 'api.github.com';
          return client;
        },
      );
    }
    // Attach the PAT only to API-host requests — never send it to a third-party
    // host (an absolute image URL in a description would otherwise leak the token).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == _apiHost) {
            options.headers['Authorization'] = 'Bearer $token';
            options.headers['Accept'] = 'application/vnd.github+json';
            options.headers['X-GitHub-Api-Version'] = '2022-11-28';
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(buildTalkerDioLogger());
  }

  /// The instance web root (`https://github.com` or the GHES root) — asset URLs
  /// are resolved against this.
  final String webBase;
  final String token;
  final String _apiHost;
  final Dio _dio;

  /// Resolves a user-entered base URL into the API base, the API host (for the
  /// auth interceptor), and the web root. github.com → `api.github.com`; a
  /// self-hosted host → `<host>/api/v3`.
  static ({String apiBase, String host, String webBase}) _resolve(String url) {
    var u = url.trim();
    if (u.isEmpty) u = 'https://github.com';
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // Tolerate a pasted API base.
    if (u.endsWith('/api/v3')) u = u.substring(0, u.length - '/api/v3'.length);
    final uri = Uri.parse(u);
    final host = uri.host.toLowerCase();
    if (host == 'github.com' ||
        host == 'www.github.com' ||
        host == 'api.github.com') {
      return (
        apiBase: 'https://api.github.com',
        host: 'api.github.com',
        webBase: 'https://github.com',
      );
    }
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    return (
      apiBase: '$scheme://${uri.host}/api/v3',
      host: uri.host,
      webBase: '$scheme://${uri.host}',
    );
  }

  // ---- identity ----

  /// The authenticated user (`GET /user`) — verifies the token and resolves the
  /// login used as the account handle.
  Future<GitHubUser> currentUser() async {
    final res = await _dio.get<dynamic>('/user');
    return GitHubUser.fromJson(_asMap(res.data));
  }

  // ---- assigned feed (global, via the Search API) ----

  Future<List<GitHubIssue>> assignedIssues() =>
      _search(GitHubIssue.fromJson, q: 'is:open is:issue assignee:@me');

  Future<List<GitHubIssue>> assignedPulls() =>
      _search(GitHubIssue.fromJson, q: 'is:open is:pr assignee:@me');

  Future<List<GitHubIssue>> reviewPulls() =>
      _search(GitHubIssue.fromJson, q: 'is:open is:pr review-requested:@me');

  // ---- repos + repo-scoped items ----

  Future<List<GitHubRepo>> repos() => _paginate(
    '/user/repos',
    GitHubRepo.fromJson,
    query: {
      'sort': 'updated',
      'affiliation': 'owner,collaborator,organization_member',
    },
  );

  Future<List<GitHubIssue>> repoIssues(
    String repo, {
    String? state,
    String? sort,
    String? direction,
    int maxPages = 20,
  }) => _paginate(
    '/repos/$repo/issues',
    GitHubIssue.fromJson,
    maxPages: maxPages,
    query: {'state': ?state, 'sort': ?sort, 'direction': ?direction},
  );

  Future<List<GitHubPull>> repoPulls(
    String repo, {
    String? state,
    String? sort,
    String? direction,
    int maxPages = 20,
  }) => _paginate(
    '/repos/$repo/pulls',
    GitHubPull.fromJson,
    maxPages: maxPages,
    query: {'state': ?state, 'sort': ?sort, 'direction': ?direction},
  );

  // ---- single detail ----

  Future<GitHubIssue> issue(String repo, String number) async {
    final res = await _dio.get<dynamic>('/repos/$repo/issues/$number');
    return GitHubIssue.fromJson(_asMap(res.data));
  }

  Future<GitHubPull> pull(String repo, String number) async {
    final res = await _dio.get<dynamic>('/repos/$repo/pulls/$number');
    return GitHubPull.fromJson(_asMap(res.data));
  }

  // ---- comments + activity ----

  Future<List<GitHubComment>> issueComments(String repo, String number) =>
      _paginate('/repos/$repo/issues/$number/comments', GitHubComment.fromJson);

  Future<GitHubComment> postIssueComment(
    String repo,
    String number,
    String body,
  ) async {
    final res = await _dio.post<dynamic>(
      '/repos/$repo/issues/$number/comments',
      data: {'body': body},
    );
    return GitHubComment.fromJson(_asMap(res.data));
  }

  Future<List<GitHubEvent>> issueEvents(String repo, String number) =>
      _paginate('/repos/$repo/issues/$number/events', GitHubEvent.fromJson);

  // ---- members (assignee picker) ----

  Future<List<GitHubUser>> assignees(String repo) =>
      _paginate('/repos/$repo/assignees', GitHubUser.fromJson);

  // ---- mutations ----

  /// Update an issue/PR (a PR is an issue): reassign and/or open/close via
  /// `PATCH /repos/:repo/issues/:number`.
  Future<void> updateIssue(
    String repo,
    String number, {
    List<String>? assignees,
    String? state,
  }) => _dio.patch<dynamic>(
    '/repos/$repo/issues/$number',
    data: {'assignees': ?assignees, 'state': ?state},
  );

  Future<void> mergePull(
    String repo,
    String number, {
    String mergeMethod = 'merge',
  }) => _dio.put<dynamic>(
    '/repos/$repo/pulls/$number/merge',
    data: {'merge_method': mergeMethod},
  );

  /// Update a PR's head branch with its base (GitHub's "Update branch" — the API
  /// has no rebase, it merges the base in). Resolves a `behind` mergeable state.
  Future<void> updateBranch(String repo, String number) =>
      _dio.put<dynamic>('/repos/$repo/pulls/$number/update-branch');

  /// Request [reviewers] (logins) on a PR. Additive — GitHub ignores logins that
  /// are already requested. POST /repos/:repo/pulls/:number/requested_reviewers.
  Future<void> requestReviewers(
    String repo,
    String number,
    List<String> reviewers,
  ) => _dio.post<dynamic>(
    '/repos/$repo/pulls/$number/requested_reviewers',
    data: {'reviewers': reviewers},
  );

  // ---- assets ----

  /// Fetches raw bytes for an authenticated asset — e.g. an inline image in an
  /// issue/PR body. Resolves [url] against the instance web root; the interceptor
  /// attaches the PAT only for instance-host requests (so a github.com CDN image
  /// never receives the token), and only an image response is accepted (an HTML
  /// error page is never returned as image bytes). Returns null on any non-image
  /// response or failure.
  Future<Uint8List?> fetchBytes(String url) async {
    final resolved = Uri.parse('$webBase/').resolveUri(Uri.parse(url));
    final res = await _dio.getUri<List<int>>(
      resolved,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
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

  // ---- helpers ----

  /// Walks a paginated list endpoint (bare JSON array) via the `Link` header's
  /// `rel="next"`, capped at [maxPages].
  Future<List<T>> _paginate<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
    int maxPages = 20,
  }) async {
    final out = <T>[];
    var page = 1;
    for (var i = 0; i < maxPages; i++) {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: {'per_page': 100, 'page': page, ...?query},
      );
      final data = res.data;
      if (data is List) {
        for (final e in data) {
          if (e is Map) out.add(fromJson(Map<String, dynamic>.from(e)));
        }
      }
      final next = _nextPage(res.headers.value('link'));
      if (next == null || next <= page) break;
      page = next;
    }
    return out;
  }

  /// Walks the Search API (`/search/issues`), whose results are wrapped in
  /// `{ items: [...] }`, via the `Link` header. Capped low ([maxPages]) — the
  /// assigned/review feeds are small and search is rate-limited.
  Future<List<T>> _search<T>(
    T Function(Map<String, dynamic>) fromJson, {
    required String q,
    int maxPages = 3,
  }) async {
    final out = <T>[];
    var page = 1;
    for (var i = 0; i < maxPages; i++) {
      final res = await _dio.get<dynamic>(
        '/search/issues',
        queryParameters: {'q': q, 'per_page': 100, 'page': page},
      );
      final data = res.data;
      final items = data is Map ? data['items'] : null;
      if (items is List) {
        for (final e in items) {
          if (e is Map) out.add(fromJson(Map<String, dynamic>.from(e)));
        }
      }
      final next = _nextPage(res.headers.value('link'));
      if (next == null || next <= page) break;
      page = next;
    }
    return out;
  }

  /// Parses the `page` of the `rel="next"` link from an RFC-5988 `Link` header,
  /// e.g. `<https://api.github.com/…?page=2>; rel="next", <…?page=5>; rel="last"`.
  int? _nextPage(String? link) {
    if (link == null || link.isEmpty) return null;
    for (final part in link.split(',')) {
      if (!part.contains('rel="next"')) continue;
      final start = part.indexOf('<');
      final end = part.indexOf('>');
      if (start < 0 || end <= start) continue;
      final url = part.substring(start + 1, end);
      final page = Uri.tryParse(url)?.queryParameters['page'];
      final n = page == null ? null : int.tryParse(page);
      if (n != null) return n;
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw DioException(
      requestOptions: RequestOptions(path: _dio.options.baseUrl),
      message: 'GitHub response was not a JSON object',
    );
  }
}
