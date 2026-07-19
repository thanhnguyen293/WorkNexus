import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/connections/data/github/github_models.dart';
import 'package:work_nexus/features/connections/data/github/github_normalize.dart';

const _acct = 'gh-acme';

List<GitHubLabel> _labels(List<String> names) => [
  for (final n in names) GitHubLabel(name: n),
];

GitHubIssue _issue({
  int number = 42,
  String state = 'open',
  List<String> labels = const [],
  String? repositoryUrl = 'https://api.github.com/repos/octo/web',
  String htmlUrl = 'https://github.com/octo/web/issues/42',
}) => GitHubIssue(
  number: number,
  title: 'An issue',
  body: 'body',
  state: state,
  labels: _labels(labels),
  htmlUrl: htmlUrl,
  repositoryUrl: repositoryUrl,
  updatedAt: '2026-07-01T10:00:00Z',
);

GitHubIssue _prItem({
  int number = 7,
  String state = 'open',
  bool draft = false,
  String? mergedAt,
  List<String> labels = const [],
}) => GitHubIssue(
  number: number,
  title: 'A PR',
  body: 'body',
  state: state,
  draft: draft,
  labels: _labels(labels),
  htmlUrl: 'https://github.com/octo/web/pull/7',
  repositoryUrl: 'https://api.github.com/repos/octo/web',
  pullRequest: GitHubPullMarker(mergedAt: mergedAt),
);

GitHubPull _pull({
  int number = 7,
  String state = 'open',
  bool draft = false,
  bool? merged,
  String? mergedAt,
  List<String> labels = const [],
}) => GitHubPull(
  number: number,
  title: 'A PR',
  body: 'body',
  state: state,
  draft: draft,
  merged: merged,
  mergedAt: mergedAt,
  mergeableState: 'clean',
  labels: _labels(labels),
  requestedReviewers: [GitHubUser(login: 'rev', name: 'Rev Iewer')],
  head: GitHubRef(ref: 'feature/x'),
  base: GitHubRef(
    ref: 'main',
    repo: GitHubRepo(fullName: 'octo/web'),
  ),
  htmlUrl: 'https://github.com/octo/web/pull/7',
);

void main() {
  group('normalizeGitHubIssue', () {
    test('open issue → todo, with repo-keyed ids and repo path', () {
      final t = normalizeGitHubIssue(_issue(), accountId: _acct);
      expect(t.id, 'gh-acme:octo/web:issue:42');
      expect(t.externalKey, '42');
      expect(t.externalType, 'Issue');
      expect(t.providerType, ProviderType.github);
      expect(t.projectId, 'gh-acme:octo/web');
      expect(t.status, UnifiedStatus.todo);
      expect(t.providerStatus, 'open');
      expect(t.url, 'https://github.com/octo/web/issues/42');
    });

    test('closed issue → done', () {
      final t = normalizeGitHubIssue(_issue(state: 'closed'), accountId: _acct);
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'closed');
    });

    test('open issue with an in-progress label → inprogress', () {
      final t = normalizeGitHubIssue(
        _issue(labels: ['Doing']),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.inprogress);
    });

    test('a blocked label wins', () {
      final t = normalizeGitHubIssue(
        _issue(labels: ['blocked']),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.blocked);
    });

    test('priority label → high priority', () {
      final t = normalizeGitHubIssue(
        _issue(labels: ['priority: high']),
        accountId: _acct,
      );
      expect(t.priority, Priority.high);
    });

    test('a P1 label → urgent priority', () {
      final t = normalizeGitHubIssue(_issue(labels: ['P1']), accountId: _acct);
      expect(t.priority, Priority.urgent);
    });

    test('no priority label → medium', () {
      final t = normalizeGitHubIssue(_issue(), accountId: _acct);
      expect(t.priority, Priority.medium);
    });

    test('parses repo from html_url when repository_url is absent', () {
      final t = normalizeGitHubIssue(
        _issue(repositoryUrl: null),
        accountId: _acct,
      );
      expect(t.projectId, 'gh-acme:octo/web');
    });
  });

  group('normalizeGitHubPullFromIssue (search feed)', () {
    test('draft PR → inprogress, raw status "draft"', () {
      final t = normalizeGitHubPullFromIssue(
        _prItem(draft: true),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.inprogress);
      expect(t.providerStatus, 'draft');
      expect(t.externalType, 'PullRequest');
      expect(t.id, 'gh-acme:octo/web:pr:7');
    });

    test('ready open PR → review', () {
      final t = normalizeGitHubPullFromIssue(_prItem(), accountId: _acct);
      expect(t.status, UnifiedStatus.review);
      expect(t.providerStatus, 'open');
    });

    test('merged PR (merged_at set) → done', () {
      final t = normalizeGitHubPullFromIssue(
        _prItem(state: 'closed', mergedAt: '2026-07-02T00:00:00Z'),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'merged');
    });
  });

  group('normalizeGitHubPull (rich)', () {
    test('draft PR → inprogress', () {
      final t = normalizeGitHubPull(_pull(draft: true), accountId: _acct);
      expect(t.status, UnifiedStatus.inprogress);
      expect(t.providerStatus, 'draft');
    });

    test('merged PR → done', () {
      final t = normalizeGitHubPull(
        _pull(state: 'closed', merged: true, mergedAt: '2026-07-02T00:00:00Z'),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'merged');
    });

    test('closed (unmerged) PR → done, raw "closed"', () {
      final t = normalizeGitHubPull(_pull(state: 'closed'), accountId: _acct);
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'closed');
    });

    test('carries PR metadata in the provider entity', () {
      final t = normalizeGitHubPull(_pull(), accountId: _acct);
      final e = t.providerEntity;
      expect(e, isA<GitHubItemEntity>());
      final g = e! as GitHubItemEntity;
      expect(g.repo, 'octo/web');
      expect(g.headBranch, 'feature/x');
      expect(g.baseBranch, 'main');
      expect(g.mergeableState, 'clean');
      expect(g.draft, false);
      expect(g.reviewers, ['Rev Iewer']);
    });

    test('search-feed and rich normalizers agree on the ticket id', () {
      // The search feed sees the issue-id and the /pulls board sees the pull-id
      // (different global ids); keying on repo:pr:number makes them converge.
      final a = normalizeGitHubPullFromIssue(
        _prItem(number: 7),
        accountId: _acct,
      );
      final b = normalizeGitHubPull(_pull(number: 7), accountId: _acct);
      expect(a.id, b.id);
      expect(a.id, 'gh-acme:octo/web:pr:7');
    });
  });

  group('repoFromUrl', () {
    test('parses an API repository_url', () {
      expect(repoFromUrl('https://api.github.com/repos/octo/web'), 'octo/web');
    });

    test('parses a web html_url', () {
      expect(repoFromUrl('https://github.com/octo/web/issues/42'), 'octo/web');
    });

    test('returns null on junk', () {
      expect(repoFromUrl(''), null);
      expect(repoFromUrl('https://github.com/onlyone'), null);
    });
  });
}
