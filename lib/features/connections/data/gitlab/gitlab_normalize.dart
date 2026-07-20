import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/util/content_hash.dart';
import 'gitlab_models.dart';

/// The GitLab object kinds we import. [marker] is the reference separator GitLab
/// uses in `references.full` (`group/web#42` for issues, `group/web!42` for MRs).
enum GitLabKind {
  issue(label: 'Issue', marker: '#'),
  mergeRequest(label: 'MergeRequest', marker: '!');

  const GitLabKind({required this.label, required this.marker});

  final String label;
  final String marker;
}

/// Maps a GitLab issue `state` (+ board labels) to the unified status.
/// `opened` is `todo`, promoted to `inprogress` when a "doing/wip" label is
/// present; a `blocked` label wins; `closed` is `done`.
UnifiedStatus mapGitLabIssueStatus(String state, List<String> labels) {
  if (_hasBlockedLabel(labels)) return UnifiedStatus.blocked;
  return switch (state) {
    'closed' => UnifiedStatus.done,
    'opened' =>
      _hasInProgressLabel(labels)
          ? UnifiedStatus.inprogress
          : UnifiedStatus.todo,
    _ => UnifiedStatus.todo,
  };
}

/// Maps a GitLab MR state (+ draft flag + labels) to the unified status.
/// `draft` is `inprogress`; a ready `opened` MR is `review`; `merged`/`closed`
/// are `done`; a `blocked` label wins.
UnifiedStatus mapGitLabMrStatus(String state, bool draft, List<String> labels) {
  if (_hasBlockedLabel(labels)) return UnifiedStatus.blocked;
  return switch (state) {
    'merged' => UnifiedStatus.done,
    'closed' => UnifiedStatus.done,
    'locked' => UnifiedStatus.blocked,
    'opened' => draft ? UnifiedStatus.inprogress : UnifiedStatus.review,
    _ => draft ? UnifiedStatus.inprogress : UnifiedStatus.review,
  };
}

/// GitLab has no native priority. We read a scoped `priority::<level>` label
/// (GitLab's convention); absent → medium.
Priority mapGitLabPriority(List<String> labels) {
  for (final raw in labels) {
    final l = raw.toLowerCase().trim();
    if (!l.startsWith('priority::')) continue;
    final level = l.substring('priority::'.length).trim();
    switch (level) {
      case 'urgent':
      case 'critical':
      case '1':
        return Priority.urgent;
      case 'high':
      case '2':
        return Priority.high;
      case 'medium':
      case 'normal':
      case '3':
        return Priority.medium;
      case 'low':
      case '4':
        return Priority.low;
    }
  }
  return Priority.medium;
}

bool _hasInProgressLabel(List<String> labels) => labels.any((l) {
  final s = l.toLowerCase();
  return s == 'doing' ||
      s == 'wip' ||
      s.contains('in progress') ||
      s.contains('in-progress') ||
      s.endsWith('::doing') ||
      s.endsWith('::in progress');
});

bool _hasBlockedLabel(List<String> labels) => labels.any((l) {
  final s = l.toLowerCase();
  return s == 'blocked' || s.endsWith('::blocked');
});

/// The full project path (e.g. `group/web`) from a `references.full`
/// (`group/web#42`), falling back to the numeric project id.
String projectPathFrom(String? full, String marker, int projectId) {
  if (full != null && full.contains(marker)) {
    final path = full.substring(0, full.lastIndexOf(marker)).trim();
    if (path.isNotEmpty) return path;
  }
  return '$projectId';
}

DateTime? parseGitLabDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Normalizes a GitLab issue into a unified [Ticket].
Ticket normalizeGitLabIssue(GitLabIssue e, {required String accountId}) {
  final path = projectPathFrom(
    e.references?.full,
    GitLabKind.issue.marker,
    e.projectId,
  );
  final title = e.title ?? '';
  final body = e.description ?? '';
  final state = e.state ?? 'opened';
  return Ticket(
    id: '$accountId:issue:${e.id}',
    accountId: accountId,
    projectId: '$accountId:$path',
    providerType: ProviderType.gitlab,
    externalKey: '${e.iid}',
    externalType: GitLabKind.issue.label,
    title: title,
    body: body,
    priority: mapGitLabPriority(e.labelNames),
    status: mapGitLabIssueStatus(state, e.labelNames),
    providerStatus: state,
    labels: e.labelNames,
    assignee: _assigneeName(e.assignees),
    url: e.webUrl,
    createdAt: parseGitLabDate(e.createdAt),
    updatedAt: parseGitLabDate(e.updatedAt),
    providerEntity: TicketProviderEntity.gitlabItem(
      projectPath: path,
      projectId: e.projectId,
      author: e.author?.display,
      labelColors: e.labelColorMap,
      labelTextColors: e.labelTextColorMap,
      upvotes: e.upvotes,
      assignees: [for (final a in e.assignees) a.display],
    ),
    sourceHash: contentHash(title, body),
  );
}

/// Normalizes a GitLab merge request into a unified [Ticket].
Ticket normalizeGitLabMergeRequest(
  GitLabMergeRequest e, {
  required String accountId,
}) {
  final path = projectPathFrom(
    e.references?.full,
    GitLabKind.mergeRequest.marker,
    e.projectId,
  );
  final title = e.title ?? '';
  final body = e.description ?? '';
  final state = e.state ?? 'opened';
  // Preserve draft in the raw status so the MR board can split draft vs review.
  final rawStatus = (state == 'opened' && e.draft) ? 'draft' : state;
  return Ticket(
    id: '$accountId:mr:${e.id}',
    accountId: accountId,
    projectId: '$accountId:$path',
    providerType: ProviderType.gitlab,
    externalKey: '${e.iid}',
    externalType: GitLabKind.mergeRequest.label,
    title: title,
    body: body,
    priority: mapGitLabPriority(e.labelNames),
    status: mapGitLabMrStatus(state, e.draft, e.labelNames),
    providerStatus: rawStatus,
    labels: e.labelNames,
    assignee: _assigneeName(e.assignees),
    url: e.webUrl,
    createdAt: parseGitLabDate(e.createdAt),
    updatedAt: parseGitLabDate(e.updatedAt),
    providerEntity: TicketProviderEntity.gitlabItem(
      projectPath: path,
      projectId: e.projectId,
      author: e.author?.display,
      labelColors: e.labelColorMap,
      labelTextColors: e.labelTextColorMap,
      sourceBranch: e.sourceBranch,
      targetBranch: e.targetBranch,
      mergeStatus: e.detailedMergeStatus ?? e.mergeStatus,
      draft: e.draft,
      upvotes: e.upvotes,
      reviewers: [for (final r in e.reviewers) r.display],
      assignees: [for (final a in e.assignees) a.display],
    ),
    sourceHash: contentHash(title, body),
  );
}

String? _assigneeName(List<GitLabUser> assignees) {
  if (assignees.isEmpty) return null;
  final name = assignees.first.display;
  return name.isEmpty ? null : name;
}
