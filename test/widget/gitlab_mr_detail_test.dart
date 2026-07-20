import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/repo_change.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/gitlab_mr_overview.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/gitlab_mr_sidebar.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/user_picker_editor.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

final _avatarBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
  'AQUBAScY42YAAAAASUVORK5CYII=',
);

Widget _emptyEditor(BuildContext context, VoidCallback close) {
  return const SizedBox.shrink();
}

void main() {
  testWidgets('GitLab MR overview renders the MR-specific layout', (
    tester,
  ) async {
    final entity =
        TicketProviderEntity.fromJson({
              'runtimeType': 'gitlabItem',
              'projectPath': 'Administrator / tbchat_socialfi',
              'author': 'Thanh',
              'authorAvatarUrl': 'https://cdn.example.com/thanh.png',
              'sourceBranch': 'develop_socialfi',
              'targetBranch': 'new_tbchat_develop',
              'mergeStatus': 'need_rebase',
              'assignees': ['Thanh'],
              'reviewers': ['Reviewer One'],
              'userAvatarUrls': {
                'Thanh': 'https://cdn.example.com/thanh.png',
                'Reviewer One': 'https://cdn.example.com/reviewer.png',
              },
              'milestoneTitle': 'Release 1.0',
              'humanTimeEstimate': '2h',
              'humanTotalTimeSpent': '1h',
            })
            as GitLabItemEntity;
    final ticket = Ticket(
      id: 'gitlab:mr:42',
      accountId: 'gitlab',
      projectId: 'project',
      providerType: ProviderType.gitlab,
      externalKey: '42',
      externalType: 'MergeRequest',
      title: 'chore(proto): regenerate protobuf files',
      body: 'Automated regeneration of Dart protobuf source files.',
      priority: Priority.medium,
      status: UnifiedStatus.inprogress,
      providerStatus: 'opened',
      sourceHash: 'hash',
      url: 'https://gitlab.example.com/group/project/-/merge_requests/42',
      labels: const ['backend', 'do-not-merge'],
      createdAt: DateTime(2026, 7, 20, 15, 48, 29),
      providerEntity: entity,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: GitLabMrOverview(
              ticket: ticket,
              entity: ticket.providerEntity! as GitLabItemEntity,
              isSyncing: false,
              onClose: () {},
              onSync: () {},
              onComment: (_) async => true,
              onCloseMergeRequest: () {},
              onApprove: () {},
              onMerge: () {},
              onRebase: () {},
              commitsLoader: () async => const Ok(<RepoCommit>[]),
              changesLoader: () async => const Ok(<RepoFileChange>[]),
              assigneeEditorBuilder: _emptyEditor,
              reviewersEditorBuilder: _emptyEditor,
              labelsEditorBuilder: _emptyEditor,
              milestoneEditorBuilder: _emptyEditor,
              timeTrackingEditorBuilder: _emptyEditor,
              avatarLoader: (_) async => _avatarBytes,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('develop_socialfi'), findsOneWidget);
    expect(find.text('new_tbchat_develop'), findsOneWidget);
    expect(find.text('Assignee'), findsOneWidget);
    expect(find.text('Reviewers'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Release 1.0'), findsOneWidget);
    expect(find.text('Estimate 2h · Spent 1h'), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(2));
    // Sidebar sections expose inline "Edit" actions.
    expect(find.text('Edit'), findsWidgets);
    expect(
      find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    // A need_rebase MR surfaces the blocked merge state + honest composer.
    expect(find.textContaining('Merge blocked'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Write a comment…'), findsOneWidget);
    // Real Commits + Changed-files sections render (empty in this stub).
    expect(find.text('Commits'), findsOneWidget);
    expect(find.text('Changed files'), findsOneWidget);
    expect(find.text('No commits'), findsOneWidget);
    // The fake Overview/Pipelines tab strip is gone.
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Pipelines'), findsNothing);
  });

  testWidgets('GitLab MR header exposes link and state actions', (
    tester,
  ) async {
    var closeCalls = 0;
    var approveCalls = 0;
    const ticket = Ticket(
      id: 'gitlab:mr:42',
      accountId: 'gitlab',
      projectId: 'project',
      providerType: ProviderType.gitlab,
      externalKey: '42',
      externalType: 'MergeRequest',
      title: 'chore(proto): regenerate protobuf files',
      body: 'Automated regeneration of Dart protobuf source files.',
      priority: Priority.medium,
      status: UnifiedStatus.inprogress,
      providerStatus: 'opened',
      sourceHash: 'hash',
      url: 'https://gitlab.example.com/group/project/-/merge_requests/42',
      providerEntity: TicketProviderEntity.gitlabItem(
        projectPath: 'Administrator / tbchat_socialfi',
        author: 'Thanh',
        sourceBranch: 'develop_socialfi',
        targetBranch: 'new_tbchat_develop',
        mergeStatus: 'mergeable',
        commitsBehind: 95,
        assignees: ['Thanh'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: GitLabMrOverview(
            ticket: ticket,
            entity: ticket.providerEntity! as GitLabItemEntity,
            isSyncing: false,
            onClose: () {},
            onSync: () {},
            onComment: (_) async => true,
            onCloseMergeRequest: () => closeCalls++,
            onApprove: () => approveCalls++,
            onMerge: () {},
            onRebase: () {},
            commitsLoader: () async => const Ok(<RepoCommit>[]),
            changesLoader: () async => const Ok(<RepoFileChange>[]),
            assigneeEditorBuilder: _emptyEditor,
            reviewersEditorBuilder: _emptyEditor,
            labelsEditorBuilder: _emptyEditor,
            milestoneEditorBuilder: _emptyEditor,
            timeTrackingEditorBuilder: _emptyEditor,
            avatarLoader: (_) async => _avatarBytes,
          ),
        ),
      ),
    );

    // Link actions are icon buttons with tooltips (no fake "Code" dropdown).
    expect(find.byTooltip('Copy link'), findsOneWidget);
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    expect(find.textContaining('Merge blocked'), findsOneWidget);
    expect(find.textContaining('95 commits behind'), findsOneWidget);

    // Approve lives in the (state-gated) merge panel; Close in the composer.
    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pump();

    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pump();

    expect(approveCalls, 1);
    expect(closeCalls, 1);
  });

  testWidgets(
    'GitLab MR sidebar opens an anchored editor instead of a dialog',
    (tester) async {
      List<String>? savedReviewers;
      const entity = GitLabItemEntity(author: 'Thanh');
      const ticket = Ticket(
        id: 'gitlab:mr:42',
        accountId: 'gitlab',
        projectId: 'project',
        providerType: ProviderType.gitlab,
        externalKey: '42',
        externalType: 'MergeRequest',
        title: 'MR',
        body: '',
        priority: Priority.medium,
        status: UnifiedStatus.review,
        providerStatus: 'opened',
        sourceHash: 'hash',
        providerEntity: entity,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: GitLabMrSidebar(
                ticket: ticket,
                entity: entity,
                assigneeEditorBuilder: _emptyEditor,
                reviewersEditorBuilder: (_, close) => UserPickerEditor(
                  currentUsers: const [],
                  multiple: true,
                  loadUsers: () async => const Ok([
                    ProviderUser(
                      account: 'Thanh',
                      displayName: 'Thanh',
                      avatarUrl: 'https://cdn.example.com/thanh.png',
                    ),
                  ]),
                  onSave: (accounts) async {
                    savedReviewers = accounts;
                    return const Ok(null);
                  },
                  onClose: close,
                  avatarLoader: (_) async => _avatarBytes,
                ),
                labelsEditorBuilder: _emptyEditor,
                milestoneEditorBuilder: _emptyEditor,
                timeTrackingEditorBuilder: _emptyEditor,
                avatarLoader: (_) async => _avatarBytes,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edit').at(1));
      await tester.pumpAndSettle();

      expect(find.text('Search users…'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.text('@Thanh'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text('@Thanh'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedReviewers, ['Thanh']);
      expect(find.text('Search users…'), findsNothing);
    },
  );
}
