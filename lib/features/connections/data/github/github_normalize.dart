import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/util/content_hash.dart';
import '../../../../core/util/priority_labels.dart';
import 'github_models.dart';

/// The GitHub object kinds we import. [label] is stored as the ticket's
/// `externalType` and drives kind-specific rendering/actions.
enum GitHubKind {
  issue(label: 'Issue'),
  pullRequest(label: 'PullRequest');

  const GitHubKind({required this.label});

  final String label;
}

/// Maps a GitHub issue `state` (+ board labels) to the unified status. `open` is
/// `todo`, promoted to `inprogress` on a "doing/wip" label; a `blocked` label
/// wins; `closed` is `done`.
UnifiedStatus mapGitHubIssueStatus(String state, List<String> labels) {
  if (_hasBlockedLabel(labels)) return UnifiedStatus.blocked;
  return switch (state) {
    'closed' => UnifiedStatus.done,
    'open' =>
      _hasInProgressLabel(labels)
          ? UnifiedStatus.inprogress
          : UnifiedStatus.todo,
    _ => UnifiedStatus.todo,
  };
}

/// Maps a GitHub PR (state + draft + merged + labels) to the unified status.
/// `merged` and `closed` are `done`; a draft is `inprogress`; a ready open PR is
/// `review`; a `blocked` label wins over an open state.
UnifiedStatus mapGitHubPrStatus(
  String state, {
  required bool draft,
  required bool merged,
  required List<String> labels,
}) {
  if (merged) return UnifiedStatus.done;
  if (_hasBlockedLabel(labels)) return UnifiedStatus.blocked;
  return switch (state) {
    'closed' => UnifiedStatus.done,
    'open' => draft ? UnifiedStatus.inprogress : UnifiedStatus.review,
    _ => draft ? UnifiedStatus.inprogress : UnifiedStatus.review,
  };
}

/// The raw provider status the PR board columns key on: draft / open / merged /
/// closed (GitHub only exposes open|closed plus separate draft & merged flags).
String githubPrRawStatus({
  required String state,
  required bool draft,
  required bool merged,
}) {
  if (merged) return 'merged';
  if (state == 'closed') return 'closed';
  return draft ? 'draft' : 'open';
}

/// GitHub has no native priority. We read a `priority: <level>` / `P1`-style
/// label if present; absent → medium. The nullable detection lives in
/// `core/util` so the UI can tell a real priority from this fallback.
Priority mapGitHubPriority(List<String> labels) =>
    gitHubPriorityFromLabels(labels) ?? Priority.medium;

bool _hasInProgressLabel(List<String> labels) => labels.any((l) {
  final s = l.toLowerCase();
  return s == 'doing' ||
      s == 'wip' ||
      s.contains('in progress') ||
      s.contains('in-progress');
});

bool _hasBlockedLabel(List<String> labels) => labels.any((l) {
  final s = l.toLowerCase();
  return s == 'blocked' || s.endsWith('::blocked');
});

/// Extracts an `owner/name` repo slug from an API `repository_url`
/// (`…/repos/owner/name`) or a web `html_url` (`…/owner/name/issues/1`).
String? repoFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final repoIdx = segs.indexOf('repos');
  if (repoIdx >= 0 && segs.length >= repoIdx + 3) {
    return '${segs[repoIdx + 1]}/${segs[repoIdx + 2]}';
  }
  if (segs.length >= 2) return '${segs[0]}/${segs[1]}';
  return null;
}

DateTime? parseGitHubDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> _labelNames(List<GitHubLabel> labels) => [
  for (final l in labels)
    if (l.name != null && l.name!.isNotEmpty) l.name!,
];

String? _assigneeName(List<GitHubUser> assignees) {
  if (assignees.isEmpty) return null;
  final name = assignees.first.display;
  return name.isEmpty ? null : name;
}

/// Normalizes a GitHub issue into a unified [Ticket]. [repoPath] is passed when
/// the fetch was repo-scoped; otherwise it's parsed from the item's URLs. The id
/// is keyed on `repo:issue:number` (not the global id) so the same issue keys
/// identically whether it came from the search feed or a repo fetch.
Ticket normalizeGitHubIssue(
  GitHubIssue e, {
  required String accountId,
  String? repoPath,
}) {
  final repo = repoPath ?? repoFromUrl(e.repositoryUrl ?? e.htmlUrl) ?? '';
  final title = e.title ?? '';
  final body = e.body ?? '';
  final state = e.state ?? 'open';
  final labels = _labelNames(e.labels);
  return Ticket(
    id: '$accountId:$repo:issue:${e.number}',
    accountId: accountId,
    projectId: '$accountId:$repo',
    providerType: ProviderType.github,
    externalKey: '${e.number}',
    externalType: GitHubKind.issue.label,
    title: title,
    body: body,
    priority: mapGitHubPriority(labels),
    status: mapGitHubIssueStatus(state, labels),
    providerStatus: state,
    labels: labels,
    assignee: _assigneeName(e.assignees),
    url: e.htmlUrl,
    createdAt: parseGitHubDate(e.createdAt),
    updatedAt: parseGitHubDate(e.updatedAt),
    providerEntity: TicketProviderEntity.githubItem(
      repo: repo,
      author: e.user?.display,
      comments: e.comments,
      assignees: [for (final a in e.assignees) a.display],
    ),
    sourceHash: contentHash(title, body),
  );
}

/// Normalizes a PR that arrived in issue shape (the Search API returns PRs as
/// issues). Merge state comes from the `pull_request.merged_at` marker; branch
/// and mergeability detail are absent here (fetched on demand via getTicket). The
/// id is keyed on `repo:pr:number`, matching [normalizeGitHubPull], so a PR seen
/// via search and via the `/pulls` board resolve to the same ticket (their global
/// issue-id and pull-id differ).
Ticket normalizeGitHubPullFromIssue(
  GitHubIssue e, {
  required String accountId,
  String? repoPath,
}) {
  final repo = repoPath ?? repoFromUrl(e.repositoryUrl ?? e.htmlUrl) ?? '';
  final title = e.title ?? '';
  final body = e.body ?? '';
  final state = e.state ?? 'open';
  final draft = e.draft ?? false;
  final merged =
      e.pullRequest?.mergedAt != null && e.pullRequest!.mergedAt!.isNotEmpty;
  final labels = _labelNames(e.labels);
  return Ticket(
    id: '$accountId:$repo:pr:${e.number}',
    accountId: accountId,
    projectId: '$accountId:$repo',
    providerType: ProviderType.github,
    externalKey: '${e.number}',
    externalType: GitHubKind.pullRequest.label,
    title: title,
    body: body,
    priority: mapGitHubPriority(labels),
    status: mapGitHubPrStatus(
      state,
      draft: draft,
      merged: merged,
      labels: labels,
    ),
    providerStatus: githubPrRawStatus(
      state: state,
      draft: draft,
      merged: merged,
    ),
    labels: labels,
    assignee: _assigneeName(e.assignees),
    url: e.htmlUrl,
    createdAt: parseGitHubDate(e.createdAt),
    updatedAt: parseGitHubDate(e.updatedAt),
    providerEntity: TicketProviderEntity.githubItem(
      repo: repo,
      author: e.user?.display,
      draft: draft,
      merged: merged,
      comments: e.comments,
      assignees: [for (final a in e.assignees) a.display],
    ),
    sourceHash: contentHash(title, body),
  );
}

/// Normalizes a full pull request (from `/pulls`), including branches, merge
/// state, and requested reviewers.
Ticket normalizeGitHubPull(
  GitHubPull e, {
  required String accountId,
  String? repoPath,
}) {
  final repo =
      repoPath ?? e.base?.repo?.fullName ?? repoFromUrl(e.htmlUrl) ?? '';
  final title = e.title ?? '';
  final body = e.body ?? '';
  final state = e.state ?? 'open';
  final merged = e.isMerged;
  final labels = _labelNames(e.labels);
  return Ticket(
    id: '$accountId:$repo:pr:${e.number}',
    accountId: accountId,
    projectId: '$accountId:$repo',
    providerType: ProviderType.github,
    externalKey: '${e.number}',
    externalType: GitHubKind.pullRequest.label,
    title: title,
    body: body,
    priority: mapGitHubPriority(labels),
    status: mapGitHubPrStatus(
      state,
      draft: e.draft,
      merged: merged,
      labels: labels,
    ),
    providerStatus: githubPrRawStatus(
      state: state,
      draft: e.draft,
      merged: merged,
    ),
    labels: labels,
    assignee: _assigneeName(e.assignees),
    url: e.htmlUrl,
    createdAt: parseGitHubDate(e.createdAt),
    updatedAt: parseGitHubDate(e.updatedAt),
    providerEntity: TicketProviderEntity.githubItem(
      repo: repo,
      author: e.user?.display,
      headBranch: e.head?.ref,
      baseBranch: e.base?.ref,
      mergeableState: e.mergeableState,
      draft: e.draft,
      merged: merged,
      comments: e.comments,
      reviewers: [for (final r in e.requestedReviewers) r.display],
      assignees: [for (final a in e.assignees) a.display],
    ),
    sourceHash: contentHash(title, body),
  );
}
