/// A single commit on a merge request / pull request (view-only detail data).
class RepoCommit {
  const RepoCommit({
    required this.sha,
    required this.shortSha,
    required this.title,
    this.author,
    this.date,
  });

  final String sha;
  final String shortSha;
  final String title;
  final String? author;
  final DateTime? date;
}

/// A single changed file on a merge request / pull request. [additions] /
/// [deletions] are line counts; [status] is the provider's change kind
/// (added/modified/deleted/renamed); [diff] is the unified-diff hunk text when
/// available (null/empty for binary or oversized files).
class RepoFileChange {
  const RepoFileChange({
    required this.path,
    this.additions = 0,
    this.deletions = 0,
    this.status,
    this.diff,
  });

  final String path;
  final int additions;
  final int deletions;
  final String? status;
  final String? diff;
}

/// Counts additions (+) and deletions (-) in a unified-diff hunk, ignoring the
/// `+++`/`---` file headers. Used when a provider returns diff text without
/// numeric counts (GitLab).
({int additions, int deletions}) countDiffLines(String? diff) {
  if (diff == null || diff.isEmpty) return (additions: 0, deletions: 0);
  var adds = 0;
  var dels = 0;
  for (final line in diff.split('\n')) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      adds++;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      dels++;
    }
  }
  return (additions: adds, deletions: dels);
}
