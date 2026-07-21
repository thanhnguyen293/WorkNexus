import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/network/api_paging.dart';
import 'gitlab_models.dart';

/// HTTP transport for the GitLab REST v4 API, bound to one account's base URL +
/// Personal Access Token (PAT). The PAT is a static credential attached as the
/// `PRIVATE-TOKEN` header by an interceptor — but only for requests to the
/// instance host, so it is never leaked to a third-party host (e.g. an external
/// image URL fetched by [fetchBytes]).
///
/// List endpoints return a bare JSON array; [_paginate] walks pages via the
/// `X-Next-Page` response header. `validateStatus` is left at dio's default
/// (throw on non-2xx) so the adapter's `_guard` can classify 401/403/404.
class GitLabClient {
  GitLabClient({required String baseUrl, required this.token, Dio? dio})
    : baseUrl = _normalizeBase(baseUrl),
      _host = Uri.parse(_normalizeBase(baseUrl)).host,
      _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '${_normalizeBase(baseUrl)}/api/v4'
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30);
    // Self-hosted GitLab may use a self-signed / untrusted TLS cert. Accept it
    // for the user's own server, but keep normal validation for gitlab.com so a
    // bad cert there is never silently trusted. Only when we own the Dio instance
    // (tests inject their own adapter).
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) =>
              host != 'gitlab.com';
          return client;
        },
      );
    }
    // Attach the PAT only to instance-host requests — never send it to a
    // third-party host (an absolute image URL in a description would otherwise
    // leak the token).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.host == _host) {
            options.headers['PRIVATE-TOKEN'] = token;
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(buildTalkerDioLogger());
  }

  final String baseUrl;
  final String token;
  final String _host;
  final Dio _dio;

  static String _normalizeBase(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http')) u = 'https://$u';
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // Tolerate a pasted API base — keep the web root.
    if (u.endsWith('/api/v4')) u = u.substring(0, u.length - '/api/v4'.length);
    return u;
  }

  // ---- identity ----

  /// The authenticated user (`GET /user`) — used to verify the token and to
  /// resolve "assigned/reviewed by me".
  Future<GitLabUser> currentUser() async {
    final res = await _dio.get<dynamic>('/user');
    return GitLabUser.fromJson(_asMap(res.data));
  }

  /// The instance version string (`GET /version`, e.g. `16.3.8`), surfaced on
  /// the connected-accounts row. Null on any failure. Also tells us whether the
  /// Markdown uploads API ([fetchBytes]) exists (17.4+).
  Future<String?> version() async {
    try {
      final res = await _dio.get<dynamic>('/version');
      final data = res.data;
      if (data is Map && data['version'] is String) {
        return data['version'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Resolves a username to a GitLab user (`GET /users?username=…`), used to map
  /// an assignee login to the numeric id that `assignee_ids` expects. Null when
  /// no user matches.
  Future<GitLabUser?> userByUsername(String username) async {
    final res = await _dio.get<dynamic>(
      '/users',
      queryParameters: {'username': username},
    );
    final data = res.data;
    if (data is List) {
      for (final e in data) {
        if (e is Map) return GitLabUser.fromJson(Map<String, dynamic>.from(e));
      }
    }
    return null;
  }

  // ---- assigned feed (global) ----

  Future<List<GitLabIssue>> assignedIssues() => _paginate(
    '/issues',
    GitLabIssue.fromJson,
    query: {
      'scope': 'assigned_to_me',
      'state': 'opened',
      'with_labels_details': 'true',
    },
  );

  Future<List<GitLabMergeRequest>> assignedMergeRequests() => _paginate(
    '/merge_requests',
    GitLabMergeRequest.fromJson,
    query: {
      'scope': 'assigned_to_me',
      'state': 'opened',
      'with_labels_details': 'true',
    },
  );

  Future<List<GitLabMergeRequest>> reviewMergeRequests(String username) async {
    try {
      return await _reviewMergeRequestsForMe();
    } on DioException catch (e) {
      if (!_isUnsupportedReviewsForMeScope(e)) rethrow;
      return _reviewMergeRequestsByUsername(username);
    }
  }

  Future<List<GitLabMergeRequest>> _reviewMergeRequestsForMe() => _paginate(
    '/merge_requests',
    GitLabMergeRequest.fromJson,
    query: {
      'scope': 'reviews_for_me',
      'state': 'opened',
      'with_labels_details': 'true',
    },
  );

  Future<List<GitLabMergeRequest>> _reviewMergeRequestsByUsername(
    String username,
  ) => _paginate(
    '/merge_requests',
    GitLabMergeRequest.fromJson,
    query: {
      'reviewer_username': username,
      'state': 'opened',
      'with_labels_details': 'true',
    },
  );

  bool _isUnsupportedReviewsForMeScope(DioException e) {
    if (e.response?.statusCode != 400) return false;
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return (data['error'] as String).contains('scope');
    }
    return data.toString().contains('scope does not have a valid value');
  }

  // ---- projects + project-scoped items ----

  Future<List<GitLabProject>> projects() => _paginate(
    '/projects',
    GitLabProject.fromJson,
    query: {'membership': 'true', 'order_by': 'last_activity_at'},
  );

  Future<List<GitLabIssue>> projectIssues(
    String projectId, {
    String? state,
    String? scope,
    String? assigneeUsername,
    String? authorUsername,
    String? orderBy,
    String? sort,
    int maxPages = 20,
  }) => _paginate(
    '/projects/$projectId/issues',
    GitLabIssue.fromJson,
    maxPages: maxPages,
    query: {
      'with_labels_details': 'true',
      'state': ?state,
      'scope': ?scope,
      'assignee_username': ?assigneeUsername,
      'author_username': ?authorUsername,
      'order_by': ?orderBy,
      'sort': ?sort,
    },
  );

  Future<List<GitLabMergeRequest>> projectMergeRequests(
    String projectId, {
    String? state,
    String? scope,
    String? assigneeUsername,
    String? authorUsername,
    String? reviewerUsername,
    String? orderBy,
    String? sort,
    int maxPages = 20,
  }) => _paginate(
    '/projects/$projectId/merge_requests',
    GitLabMergeRequest.fromJson,
    maxPages: maxPages,
    query: {
      'with_labels_details': 'true',
      'state': ?state,
      'scope': ?scope,
      'assignee_username': ?assigneeUsername,
      'author_username': ?authorUsername,
      'reviewer_username': ?reviewerUsername,
      'order_by': ?orderBy,
      'sort': ?sort,
    },
  );

  // ---- single detail ----

  Future<GitLabIssue> issue(String projectId, String iid) async {
    final res = await _dio.get<dynamic>(
      '/projects/$projectId/issues/$iid',
      queryParameters: {'with_labels_details': 'true'},
    );
    return GitLabIssue.fromJson(_asMap(res.data));
  }

  Future<GitLabMergeRequest> mergeRequest(String projectId, String iid) async {
    final res = await _dio.get<dynamic>(
      '/projects/$projectId/merge_requests/$iid',
      queryParameters: {'with_labels_details': 'true'},
    );
    return GitLabMergeRequest.fromJson(_asMap(res.data));
  }

  // ---- notes (comments + system activity) ----

  Future<List<GitLabNote>> issueNotes(String projectId, String iid) =>
      _paginate(
        '/projects/$projectId/issues/$iid/notes',
        GitLabNote.fromJson,
        query: {'sort': 'asc', 'order_by': 'created_at'},
      );

  Future<List<GitLabNote>> mrNotes(String projectId, String iid) => _paginate(
    '/projects/$projectId/merge_requests/$iid/notes',
    GitLabNote.fromJson,
    query: {'sort': 'asc', 'order_by': 'created_at'},
  );

  Future<GitLabNote> postIssueNote(
    String projectId,
    String iid,
    String body,
  ) async {
    final res = await _dio.post<dynamic>(
      '/projects/$projectId/issues/$iid/notes',
      data: {'body': body},
    );
    return GitLabNote.fromJson(_asMap(res.data));
  }

  Future<GitLabNote> postMrNote(
    String projectId,
    String iid,
    String body,
  ) async {
    final res = await _dio.post<dynamic>(
      '/projects/$projectId/merge_requests/$iid/notes',
      data: {'body': body},
    );
    return GitLabNote.fromJson(_asMap(res.data));
  }

  // ---- members (assignee picker) ----

  Future<List<GitLabUser>> members(String projectId) =>
      _paginate('/projects/$projectId/members/all', GitLabUser.fromJson);

  Future<List<GitLabLabel>> projectLabels(String projectId) =>
      _paginate('/projects/$projectId/labels', GitLabLabel.fromJson);

  Future<List<GitLabMilestone>> projectMilestones(String projectId) =>
      _paginate(
        '/projects/$projectId/milestones',
        GitLabMilestone.fromJson,
        query: {'state': 'active', 'include_parent_milestones': true},
      );

  // ---- mutations ----

  Future<void> updateIssue(
    String projectId,
    String iid, {
    List<int>? assigneeIds,
    String? stateEvent,
  }) => _dio.put<dynamic>(
    '/projects/$projectId/issues/$iid',
    data: {'assignee_ids': ?assigneeIds, 'state_event': ?stateEvent},
  );

  Future<void> updateMergeRequest(
    String projectId,
    String iid, {
    List<int>? assigneeIds,
    List<int>? reviewerIds,
    List<String>? labels,
    int? milestoneId,
    String? stateEvent,
  }) => _dio.put<dynamic>(
    '/projects/$projectId/merge_requests/$iid',
    data: {
      'assignee_ids': ?assigneeIds,
      'reviewer_ids': ?reviewerIds,
      'labels': ?labels?.join(','),
      'milestone_id': ?milestoneId,
      'state_event': ?stateEvent,
    },
  );

  Future<void> setMergeRequestTimeEstimate(
    String projectId,
    String iid,
    String duration,
  ) => _dio.post<dynamic>(
    '/projects/$projectId/merge_requests/$iid/time_estimate',
    data: {'duration': duration},
  );

  Future<void> resetMergeRequestTimeEstimate(String projectId, String iid) =>
      _dio.post<dynamic>(
        '/projects/$projectId/merge_requests/$iid/reset_time_estimate',
      );

  Future<void> addMergeRequestSpentTime(
    String projectId,
    String iid,
    String duration,
  ) => _dio.post<dynamic>(
    '/projects/$projectId/merge_requests/$iid/add_spent_time',
    data: {'duration': duration},
  );

  Future<void> resetMergeRequestSpentTime(String projectId, String iid) =>
      _dio.post<dynamic>(
        '/projects/$projectId/merge_requests/$iid/reset_spent_time',
      );

  Future<void> mergeMergeRequest(String projectId, String iid) =>
      _dio.put<dynamic>('/projects/$projectId/merge_requests/$iid/merge');

  /// Approve a merge request as the authenticated user.
  Future<void> approveMergeRequest(String projectId, String iid) =>
      _dio.post<dynamic>('/projects/$projectId/merge_requests/$iid/approve');

  /// Rebase a merge request onto its target branch. Resolves a `need_rebase`
  /// detailed merge status. PUT /projects/:id/merge_requests/:iid/rebase.
  Future<void> rebaseMergeRequest(String projectId, String iid) =>
      _dio.put<dynamic>('/projects/$projectId/merge_requests/$iid/rebase');

  /// Count commits present in [targetBranch] but missing from [sourceBranch].
  /// GitLab web uses this to force rebase on fast-forward/semi-linear projects
  /// even when `detailed_merge_status` still says `mergeable`.
  Future<int?> commitsBehindTarget(
    String projectId, {
    required String sourceBranch,
    required String targetBranch,
  }) async {
    final res = await _dio.get<dynamic>(
      '/projects/$projectId/repository/compare',
      queryParameters: {
        'from': sourceBranch,
        'to': targetBranch,
        'straight': 'true',
        'per_page': kDefaultApiPageLimit,
      },
    );
    final data = _asMap(res.data);
    final commits = data['commits'];
    return commits is List ? commits.length : null;
  }

  // ---- MR commits + diffs (detail view) ----

  /// Commits on a merge request (`GET …/merge_requests/:iid/commits`), newest
  /// first. Raw maps — the adapter maps them to [RepoCommit].
  Future<List<Map<String, dynamic>>> mergeRequestCommits(
    String projectId,
    String iid,
  ) => _paginate(
    '/projects/$projectId/merge_requests/$iid/commits',
    (m) => m,
    maxPages: 5,
  );

  /// Per-file diffs on a merge request (`GET …/merge_requests/:iid/diffs`,
  /// GitLab 15.7+). Raw maps ({old_path,new_path,diff,new_file,deleted_file,…}).
  Future<List<Map<String, dynamic>>> mergeRequestDiffs(
    String projectId,
    String iid,
  ) => _paginate(
    '/projects/$projectId/merge_requests/$iid/diffs',
    (m) => m,
    maxPages: 5,
  );

  // ---- assets ----

  /// Fetches raw bytes for an authenticated inline asset — e.g. an `/uploads/…`
  /// image embedded in an issue/MR description. Only an image response is
  /// accepted (so an HTML error/login page is never rendered as an image);
  /// returns null on any non-image response or failure.
  ///
  /// GitLab renders a markdown upload as a **project-web-relative** link
  /// (`/uploads/<secret>/<file>`). That web path is served ONLY against a
  /// session cookie — a Personal Access Token is rejected there — so fetching it
  /// directly never works for a PAT integration. Instead we hit the **Markdown
  /// uploads API** (`GET /projects/:id/uploads/:secret/:filename`, GitLab 17.4+),
  /// which DOES honor the `PRIVATE-TOKEN` header. [projectId] (preferred) or
  /// [projectPath] identifies the owning project. Absolute URLs (and any
  /// non-upload relative link) are fetched as-is against the instance.
  Future<Uint8List?> fetchBytes(
    String url, {
    String? projectPath,
    int? projectId,
  }) async {
    final resolved = _resolveAsset(url, projectPath, projectId);
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

  /// Resolves an inline-asset [url] from a description into an absolute URI.
  ///
  /// A bare project-relative markdown upload (`/uploads/<secret>/<file>`) is
  /// mapped to the Markdown uploads **API** endpoint for its project — the only
  /// PAT-authenticated way to read it (the web `/uploads/…` path needs a session
  /// cookie). The project ref is the numeric [projectId] when known, else the
  /// URL-encoded [projectPath]. Absolute URLs are used as-is; any other relative
  /// link resolves against the instance root.
  Uri _resolveAsset(String url, String? projectPath, int? projectId) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return parsed;
    final segments = parsed.pathSegments;
    final project = projectId != null && projectId > 0
        ? '$projectId'
        : (projectPath != null && projectPath.isNotEmpty ? projectPath : null);
    if (project != null &&
        segments.length >= 3 &&
        segments.first == 'uploads') {
      // `.replace(pathSegments:)` percent-encodes each segment (so a project
      // *path* like `group/web` becomes the `group%2Fweb` the API expects, and
      // any base-URL subpath is preserved).
      final base = Uri.parse(baseUrl);
      return base.replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          'api',
          'v4',
          'projects',
          project,
          'uploads',
          ...segments.skip(1),
        ],
      );
    }
    return Uri.parse('$baseUrl/').resolveUri(parsed);
  }

  // ---- helpers ----

  /// Walks a paginated list endpoint via the `X-Next-Page` header, accumulating
  /// typed items. Stops when the header is empty or doesn't advance (defensive
  /// against a server that ignores `page`), capped at [maxPages].
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
        queryParameters: {
          'per_page': kDefaultApiPageLimit,
          'page': page,
          ...?query,
        },
      );
      final data = res.data;
      if (data is List) {
        for (final e in data) {
          if (e is Map) out.add(fromJson(Map<String, dynamic>.from(e)));
        }
      }
      final next = res.headers.value('x-next-page');
      final parsed = next == null || next.isEmpty ? null : int.tryParse(next);
      if (parsed == null || parsed <= page) break;
      page = parsed;
    }
    return out;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw DioException(
      requestOptions: RequestOptions(path: _dio.options.baseUrl),
      message: 'GitLab response was not a JSON object',
    );
  }
}
