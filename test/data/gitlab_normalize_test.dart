import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_models.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_normalize.dart';

const _acct = 'gl-acme';

GitLabIssue _issue({
  int id = 1001,
  int iid = 42,
  int projectId = 7,
  String state = 'opened',
  List<String> labels = const [],
  String? full = 'group/web#42',
}) => GitLabIssue(
  id: id,
  iid: iid,
  projectId: projectId,
  title: 'An issue',
  description: 'body',
  state: state,
  labels: [for (final l in labels) GitLabLabel(name: l)],
  webUrl: 'https://gl/group/web/-/issues/42',
  references: full == null ? null : GitLabReferences(full: full),
  updatedAt: '2026-07-01T10:00:00Z',
);

GitLabMergeRequest _mr({
  int id = 2001,
  int iid = 7,
  int projectId = 7,
  String state = 'opened',
  bool draft = false,
  List<String> labels = const [],
  String? full = 'group/web!7',
}) => GitLabMergeRequest(
  id: id,
  iid: iid,
  projectId: projectId,
  title: 'An MR',
  description: 'body',
  state: state,
  draft: draft,
  labels: [for (final l in labels) GitLabLabel(name: l)],
  sourceBranch: 'feature/x',
  targetBranch: 'main',
  webUrl: 'https://gl/group/web/-/merge_requests/7',
  references: full == null ? null : GitLabReferences(full: full),
);

void main() {
  group('normalizeGitLabIssue', () {
    test('opened issue → todo, with stable ids and project path', () {
      final t = normalizeGitLabIssue(_issue(), accountId: _acct);
      expect(t.id, 'gl-acme:issue:1001');
      expect(t.externalKey, '42');
      expect(t.externalType, 'Issue');
      expect(t.providerType, ProviderType.gitlab);
      expect(t.projectId, 'gl-acme:group/web');
      expect(t.status, UnifiedStatus.todo);
      expect(t.providerStatus, 'opened');
      expect(t.url, 'https://gl/group/web/-/issues/42');
    });

    test('closed issue → done', () {
      final t = normalizeGitLabIssue(_issue(state: 'closed'), accountId: _acct);
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'closed');
    });

    test('opened issue with an in-progress label → inprogress', () {
      final t = normalizeGitLabIssue(
        _issue(labels: ['Doing']),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.inprogress);
    });

    test('a blocked label wins', () {
      final t = normalizeGitLabIssue(
        _issue(labels: ['blocked']),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.blocked);
    });

    test('priority::high label → high priority', () {
      final t = normalizeGitLabIssue(
        _issue(labels: ['priority::high']),
        accountId: _acct,
      );
      expect(t.priority, Priority.high);
    });

    test('no priority label → medium', () {
      final t = normalizeGitLabIssue(_issue(), accountId: _acct);
      expect(t.priority, Priority.medium);
    });

    test('falls back to the numeric project id without references', () {
      final t = normalizeGitLabIssue(_issue(full: null), accountId: _acct);
      expect(t.projectId, 'gl-acme:7');
    });
  });

  group('normalizeGitLabMergeRequest', () {
    test('draft MR → inprogress, raw status "draft"', () {
      final t = normalizeGitLabMergeRequest(_mr(draft: true), accountId: _acct);
      expect(t.status, UnifiedStatus.inprogress);
      expect(t.providerStatus, 'draft');
      expect(t.externalType, 'MergeRequest');
      expect(t.id, 'gl-acme:mr:2001');
    });

    test('ready opened MR → review', () {
      final t = normalizeGitLabMergeRequest(_mr(), accountId: _acct);
      expect(t.status, UnifiedStatus.review);
      expect(t.providerStatus, 'opened');
    });

    test('merged MR → done', () {
      final t = normalizeGitLabMergeRequest(
        _mr(state: 'merged'),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.done);
      expect(t.providerStatus, 'merged');
    });

    test('closed MR → done', () {
      final t = normalizeGitLabMergeRequest(
        _mr(state: 'closed'),
        accountId: _acct,
      );
      expect(t.status, UnifiedStatus.done);
    });

    test('carries MR metadata in the provider entity', () {
      final t = normalizeGitLabMergeRequest(_mr(), accountId: _acct);
      final e = t.providerEntity;
      expect(e, isA<GitLabItemEntity>());
      final g = e! as GitLabItemEntity;
      expect(g.projectPath, 'group/web');
      expect(g.projectId, 7);
      expect(g.sourceBranch, 'feature/x');
      expect(g.targetBranch, 'main');
      expect(g.draft, false);
    });
  });

  group('projectPathFrom', () {
    test('parses an issue reference', () {
      expect(projectPathFrom('group/web#42', '#', 7), 'group/web');
    });

    test('parses an MR reference', () {
      expect(projectPathFrom('a/b/c!12', '!', 7), 'a/b/c');
    });

    test('falls back to the numeric id when full is null', () {
      expect(projectPathFrom(null, '#', 7), '7');
    });
  });
}
