part of 'gitlab_adapter.dart';

/// Merge request fields and contents: reviewers, labels, milestone, time
/// tracking, and the commit / per-file diff lists of the detail view.
mixin _GitLabMergeRequests on _GitLabAdapterBase {
  /// Set the MR reviewers (replaces the current set). Resolves the selected
  /// logins to member ids via the project member list.
  @override
  Future<Result<bool>> setReviewers(
    Ticket ticket,
    List<String> logins,
  ) => _guard(() async {
    final ref = _projectRef(ticket);
    final selected = logins.toSet();
    final members = await _client.members(ref);
    final ids = <int>[
      for (final m in members)
        if (m.username != null && m.id != null && selected.contains(m.username))
          m.id!,
    ];
    await _client.updateMergeRequest(ref, ticket.externalKey, reviewerIds: ids);
    return true;
  });

  @override
  Future<Result<bool>> setLabels(Ticket ticket, List<String> labels) =>
      _guard(() async {
        await _client.updateMergeRequest(
          _projectRef(ticket),
          ticket.externalKey,
          labels: labels,
        );
        return true;
      });

  @override
  Future<Result<bool>> setMilestone(Ticket ticket, int? milestoneId) =>
      _guard(() async {
        await _client.updateMergeRequest(
          _projectRef(ticket),
          ticket.externalKey,
          milestoneId: milestoneId ?? 0,
        );
        return true;
      });

  @override
  Future<Result<bool>> updateTimeTracking(
    Ticket ticket, {
    String? estimate,
    String? spent,
    bool resetEstimate = false,
    bool resetSpent = false,
  }) => _guard(() async {
    final ref = _projectRef(ticket);
    if (resetEstimate) {
      await _client.resetMergeRequestTimeEstimate(ref, ticket.externalKey);
    } else if (estimate != null && estimate.trim().isNotEmpty) {
      await _client.setMergeRequestTimeEstimate(
        ref,
        ticket.externalKey,
        estimate.trim(),
      );
    }
    if (resetSpent) {
      await _client.resetMergeRequestSpentTime(ref, ticket.externalKey);
    } else if (spent != null && spent.trim().isNotEmpty) {
      await _client.addMergeRequestSpentTime(
        ref,
        ticket.externalKey,
        spent.trim(),
      );
    }
    return true;
  });

  /// Commits on a merge request (detail view). GitLab-specific — off-interface.
  Future<Result<List<RepoCommit>>> listMergeRequestCommits(Ticket ticket) =>
      _guard(() async {
        final ref = _projectRef(ticket);
        final rows = await _client.mergeRequestCommits(ref, ticket.externalKey);
        return [
          for (final r in rows)
            RepoCommit(
              sha: '${r['id'] ?? ''}',
              shortSha: '${r['short_id'] ?? r['id'] ?? ''}',
              title: '${r['title'] ?? r['message'] ?? ''}'.trim(),
              author: r['author_name'] as String?,
              date: parseGitLabDate(
                (r['authored_date'] ?? r['created_at']) as String?,
              ),
            ),
        ];
      });

  /// Per-file diffs on a merge request (detail view). GitLab-specific.
  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(Ticket ticket) =>
      _guard(() async {
        final ref = _projectRef(ticket);
        final rows = await _client.mergeRequestDiffs(ref, ticket.externalKey);
        return [for (final r in rows) _fileChange(r)];
      });

  RepoFileChange _fileChange(Map<String, dynamic> r) {
    final newPath = r['new_path'] as String?;
    final oldPath = r['old_path'] as String?;
    final path = (newPath != null && newPath.isNotEmpty)
        ? newPath
        : (oldPath ?? '');
    final diff = r['diff'] as String?;
    final counts = countDiffLines(diff);
    final status = r['new_file'] == true
        ? 'added'
        : r['deleted_file'] == true
        ? 'deleted'
        : r['renamed_file'] == true
        ? 'renamed'
        : 'modified';
    return RepoFileChange(
      path: path,
      additions: counts.additions,
      deletions: counts.deletions,
      status: status,
      diff: diff,
    );
  }
}
