part of 'gitlab_client.dart';

/// Read endpoints: identity (current user, version, username lookup), the
/// assigned / review-requested feeds, projects with their issue and MR lists,
/// and single issue / MR detail.
mixin _GitLabReads on _GitLabClientBase {
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
}
