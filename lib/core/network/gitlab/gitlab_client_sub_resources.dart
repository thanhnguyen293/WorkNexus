part of 'gitlab_client.dart';

/// Sub-resources of an item or project: issue / MR notes (list + post), project
/// members, labels and milestones, and a merge request's commits and diffs.
mixin _GitLabSubResources on _GitLabClientBase {
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
}
