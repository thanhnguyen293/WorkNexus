import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/repo_change.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/github_pr_overview.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

final _avatarBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
  'AQUBAScY42YAAAAASUVORK5CYII=',
);

Widget _emptyEditor(BuildContext context, VoidCallback close) {
  return const SizedBox.shrink();
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  home: Scaffold(body: child),
);

Ticket _pr({required String providerStatus, required String mergeableState}) =>
    Ticket(
      id: 'github:pr:7',
      accountId: 'github',
      projectId: 'github:acme/web',
      providerType: ProviderType.github,
      externalKey: '7',
      externalType: 'PullRequest',
      title: 'feat: add dashboard',
      body: 'Adds the analytics dashboard.',
      priority: Priority.medium,
      status: UnifiedStatus.review,
      providerStatus: providerStatus,
      sourceHash: 'hash',
      url: 'https://github.com/acme/web/pull/7',
      labels: const ['frontend', 'github-repo:acme/web'],
      createdAt: DateTime(2026, 7, 20, 10),
      providerEntity: GitHubItemEntity(
        repo: 'acme/web',
        author: 'octocat',
        headBranch: 'feature/dashboard',
        baseBranch: 'main',
        mergeableState: mergeableState,
        reviewers: const ['reviewer-one'],
        assignees: const ['octocat'],
      ),
    );

void main() {
  testWidgets('GitHub PR overview renders the PR-specific layout', (
    tester,
  ) async {
    final ticket = _pr(providerStatus: 'open', mergeableState: 'behind');
    await tester.pumpWidget(
      _host(
        GitHubPrOverview(
          ticket: ticket,
          entity: ticket.providerEntity! as GitHubItemEntity,
          isSyncing: false,
          onClose: () {},
          onSync: () {},
          onComment: (_) async => true,
          onCloseItem: () {},
          onReopen: () {},
          onMerge: () {},
          onUpdateBranch: () {},
          commitsLoader: () async => const Ok(<RepoCommit>[]),
          changesLoader: () async => const Ok(<RepoFileChange>[]),
          assigneeEditorBuilder: _emptyEditor,
          reviewersEditorBuilder: _emptyEditor,
          avatarLoader: (_) async => _avatarBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('feature/dashboard'), findsOneWidget);
    expect(find.text('main'), findsOneWidget);
    expect(find.text('Assignee'), findsOneWidget);
    expect(find.text('Reviewers'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    // The synthetic github-repo label is filtered out; the user label shows.
    expect(find.text('frontend'), findsOneWidget);
    expect(find.text('github-repo:acme/web'), findsNothing);
    // Behind base → "Update branch" + Merge, and the out-of-date notice.
    expect(find.textContaining('out of date'), findsOneWidget);
    expect(find.text('Update branch'), findsOneWidget);
    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Write a comment…'), findsOneWidget);
    // Commits + Changed files now live on their own tabs.
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Commits'), findsOneWidget);
    expect(find.text('Changed files'), findsOneWidget);

    // Switching tabs reveals the (empty-stub) code-review sections.
    await tester.tap(find.text('Commits'));
    await tester.pumpAndSettle();
    expect(find.text('No commits'), findsOneWidget);

    await tester.tap(find.text('Changed files'));
    await tester.pumpAndSettle();
    expect(find.text('No changed files'), findsOneWidget);
  });

  testWidgets('GitHub PR merge + close callbacks fire on an open PR', (
    tester,
  ) async {
    var mergeCalls = 0;
    var closeCalls = 0;
    final ticket = _pr(providerStatus: 'open', mergeableState: 'clean');
    await tester.pumpWidget(
      _host(
        GitHubPrOverview(
          ticket: ticket,
          entity: ticket.providerEntity! as GitHubItemEntity,
          isSyncing: false,
          onClose: () {},
          onSync: () {},
          onComment: (_) async => true,
          onCloseItem: () => closeCalls++,
          onReopen: () {},
          onMerge: () => mergeCalls++,
          onUpdateBranch: () {},
          commitsLoader: () async => const Ok(<RepoCommit>[]),
          changesLoader: () async => const Ok(<RepoFileChange>[]),
          assigneeEditorBuilder: _emptyEditor,
          reviewersEditorBuilder: _emptyEditor,
          avatarLoader: (_) async => _avatarBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Not behind → no "Update branch".
    expect(find.text('Update branch'), findsNothing);

    await tester.ensureVisible(find.text('Merge'));
    await tester.tap(find.text('Merge'));
    await tester.pump();

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pump();

    expect(mergeCalls, 1);
    expect(closeCalls, 1);
  });

  testWidgets('GitHub PR shows Reopen when closed (not merged)', (
    tester,
  ) async {
    var reopenCalls = 0;
    final ticket = _pr(providerStatus: 'closed', mergeableState: 'unknown');
    await tester.pumpWidget(
      _host(
        GitHubPrOverview(
          ticket: ticket,
          entity: ticket.providerEntity! as GitHubItemEntity,
          isSyncing: false,
          onClose: () {},
          onSync: () {},
          onComment: (_) async => true,
          onCloseItem: () {},
          onReopen: () => reopenCalls++,
          onMerge: () {},
          onUpdateBranch: () {},
          commitsLoader: () async => const Ok(<RepoCommit>[]),
          changesLoader: () async => const Ok(<RepoFileChange>[]),
          assigneeEditorBuilder: _emptyEditor,
          reviewersEditorBuilder: _emptyEditor,
          avatarLoader: (_) async => _avatarBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Closed → no Merge, but a Reopen; the composer's Close button is hidden.
    expect(find.text('Merge'), findsNothing);
    expect(find.text('Close'), findsNothing);
    await tester.ensureVisible(find.text('Reopen'));
    await tester.tap(find.text('Reopen'));
    await tester.pump();
    expect(reopenCalls, 1);
  });
}
