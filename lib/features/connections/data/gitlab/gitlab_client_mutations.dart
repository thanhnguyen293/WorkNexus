part of 'gitlab_client.dart';

/// Write endpoints: issue / MR updates, MR time tracking, merge / approve /
/// rebase, plus the compare count that tells whether an MR needs a rebase.
mixin _GitLabMutations on _GitLabClientBase {
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
}
