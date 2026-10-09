part of 'github_adapter.dart';

/// Pull request reviewers and contents: review requests, and the commit /
/// changed-file lists of the detail view.
mixin _GitHubPullRequests on _GitHubAdapterBase {
  /// Request [logins] as reviewers on a PR (additive — GitHub ignores logins
  /// already requested; removing a reviewer isn't supported through this path).
  Future<Result<bool>> setReviewers(Ticket ticket, List<String> logins) =>
      _guard(() async {
        if (logins.isNotEmpty) {
          await _client.requestReviewers(
            _repoRef(ticket),
            ticket.externalKey,
            logins,
          );
        }
        return true;
      });

  /// Commits on a pull request (detail view). GitHub-specific — off-interface.
  Future<Result<List<RepoCommit>>> listPullCommits(Ticket ticket) =>
      _guard(() async {
        final ref = _repoRef(ticket);
        final rows = await _client.pullCommits(ref, ticket.externalKey);
        return [for (final r in rows) _commit(r)];
      });

  /// Changed files on a pull request (detail view). GitHub-specific.
  Future<Result<List<RepoFileChange>>> listPullFiles(Ticket ticket) =>
      _guard(() async {
        final ref = _repoRef(ticket);
        final rows = await _client.pullFiles(ref, ticket.externalKey);
        return [
          for (final r in rows)
            RepoFileChange(
              path: '${r['filename'] ?? ''}',
              additions: (r['additions'] as num?)?.toInt() ?? 0,
              deletions: (r['deletions'] as num?)?.toInt() ?? 0,
              status: r['status'] as String?,
              diff: r['patch'] as String?,
            ),
        ];
      });

  RepoCommit _commit(Map<String, dynamic> r) {
    final sha = '${r['sha'] ?? ''}';
    final commitRaw = r['commit'];
    final commit = commitRaw is Map
        ? Map<String, dynamic>.from(commitRaw)
        : const <String, dynamic>{};
    final message = commit['message'] as String? ?? '';
    final authorRaw = commit['author'];
    final author = authorRaw is Map
        ? Map<String, dynamic>.from(authorRaw)
        : const <String, dynamic>{};
    return RepoCommit(
      sha: sha,
      shortSha: sha.length >= 7 ? sha.substring(0, 7) : sha,
      title: message.split('\n').first.trim(),
      author: author['name'] as String?,
      date: parseGitHubDate(author['date'] as String?),
    );
  }
}
