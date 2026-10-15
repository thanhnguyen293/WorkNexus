import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/user_picker_editor.dart';
import 'package:work_nexus/tools/gitlab/presentation/detail/gitlab_mr_commands.dart';
import 'package:work_nexus/tools/gitlab/presentation/detail/gitlab_mr_overview.dart';
import 'package:work_nexus/tools/gitlab/presentation/detail/gitlab_mr_sidebar.dart';

final _avatarBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
  'AQUBAScY42YAAAAASUVORK5CYII=',
);

Widget _emptyEditor(BuildContext context, VoidCallback close) {
  return const SizedBox.shrink();
}

/// Records each MR command; while [pending] is set, commands stay running
/// until it completes.
class _FakeCommands {
  final calls = <String>[];
  Completer<void>? pending;

  Future<void> _record(String name) {
    calls.add(name);
    return pending?.future ?? Future.value();
  }

  GitLabMrCommands get commands => GitLabMrCommands(
    approve: () => _record('approve'),
    unapprove: () => _record('unapprove'),
    merge: ({required squash, required removeSourceBranch}) =>
        _record('merge squash=$squash remove=$removeSourceBranch'),
    rebase: () => _record('rebase'),
    close: () => _record('close'),
    reopen: () => _record('reopen'),
    setDraft: (draft) => _record('draft=$draft'),
  );
}

Widget _overview(Ticket ticket, GitLabMrCommands commands) => ProviderScope(
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
        commands: commands,
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

Ticket _mr(String status, TicketProviderEntity entity) => Ticket(
  id: 'gitlab:mr:42',
  accountId: 'gitlab',
  projectId: 'project',
  providerType: ProviderType.gitlab,
  externalKey: '42',
  externalType: 'MergeRequest',
  title: 'chore(proto): regenerate protobuf files',
  body: 'Automated regeneration of Dart protobuf source files.',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: status,
  sourceHash: 'hash',
  url: 'https://gitlab.example.com/group/project/-/merge_requests/42',
  providerEntity: entity,
);

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
              commands: _FakeCommands().commands,
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
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Release 1.0'), findsOneWidget);
    expect(find.text('Estimate 2h · Spent 1h'), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(2));
    // Sidebar sections expose inline "Edit" actions.
    expect(find.text('Edit'), findsWidgets);
    expect(
      find.ancestor(
        of: find.byIcon(LucideIcons.plus300),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
    // A need_rebase MR surfaces the blocked merge state + honest composer.
    expect(find.textContaining('Merge blocked'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Write a comment…'), findsOneWidget);
    // Commits + Changed files now live on their own tabs (real, not the old
    // fake Overview/Pipelines strip).
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Commits'), findsOneWidget);
    expect(find.text('Changed files'), findsOneWidget);
    expect(find.text('Pipelines'), findsNothing);

    // Switching tabs reveals the (empty-stub) code-review sections.
    await tester.tap(find.text('Commits'));
    await tester.pumpAndSettle();
    expect(find.text('No commits'), findsOneWidget);

    await tester.tap(find.text('Changed files'));
    await tester.pumpAndSettle();
    expect(find.text('No changed files'), findsOneWidget);
  });

  testWidgets('GitLab MR header exposes link and state actions', (
    tester,
  ) async {
    final fake = _FakeCommands();
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
              commands: fake.commands,
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

    // The repository it belongs to, above the title.
    expect(find.text('Administrator / tbchat_socialfi'), findsOneWidget);
    expect(find.text('!42'), findsOneWidget);
    expect(find.byTooltip('Open the project in the browser'), findsOneWidget);

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

    expect(fake.calls, ['approve', 'close']);
  });

  testWidgets('Rebase spins until the rebase has finished', (tester) async {
    final fake = _FakeCommands()..pending = Completer<void>();
    await tester.pumpWidget(
      _overview(
        _mr(
          'opened',
          const TicketProviderEntity.gitlabItem(mergeStatus: 'need_rebase'),
        ),
        fake.commands,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rebase'));
    await tester.pump();
    expect(fake.calls, ['rebase']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A second press while it runs does nothing.
    await tester.tap(
      find.byType(CircularProgressIndicator),
      warnIfMissed: false,
    );
    expect(fake.calls, ['rebase']);

    fake.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a draft MR is blocked until marked ready', (tester) async {
    final fake = _FakeCommands();
    await tester.pumpWidget(
      _overview(
        _mr('draft', const TicketProviderEntity.gitlabItem(draft: true)),
        fake.commands,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('is a draft'), findsOneWidget);
    expect(find.text('Merge'), findsNothing);
    await tester.tap(find.text('Mark as ready'));
    await tester.pump();
    expect(fake.calls, ['draft=false']);
  });

  testWidgets('merging sends the chosen options', (tester) async {
    final fake = _FakeCommands();
    await tester.pumpWidget(
      _overview(
        _mr(
          'opened',
          const TicketProviderEntity.gitlabItem(
            mergeStatus: 'mergeable',
            removeSourceBranch: true,
          ),
        ),
        fake.commands,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Squash commits'));
    await tester.pump();
    await tester.tap(find.text('Merge'));
    await tester.pump();
    expect(fake.calls, ['merge squash=true remove=true']);
  });

  testWidgets('a merged MR says who merged and who approved', (tester) async {
    await tester.pumpWidget(
      _overview(
        _mr(
          'merged',
          const TicketProviderEntity.gitlabItem(
            targetBranch: 'new_develop_socialfi',
            mergedBy: 'Thanh',
            mergeCommitSha: 'a78f2b73deadbeef',
            squashCommitSha: 'a78f2b73deadbeef',
            removeSourceBranch: true,
            approvedBy: ['Thanh'],
            userHasApproved: true,
            reviewers: ['Thanh'],
          ),
        ),
        _FakeCommands().commands,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved by you'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.textContaining('Merged by Thanh'), findsOneWidget);
    expect(find.textContaining('a78f2b73'), findsOneWidget);
    expect(find.text('Commits were squashed.'), findsOneWidget);
    expect(find.text('Deleted the source branch.'), findsOneWidget);
    expect(find.text('Revert'), findsOneWidget);
    expect(find.byTooltip('Approved'), findsOneWidget);
  });

  testWidgets('the header menu marks an open MR as draft', (tester) async {
    final fake = _FakeCommands();
    await tester.pumpWidget(
      _overview(
        _mr(
          'opened',
          const TicketProviderEntity.gitlabItem(projectPath: 'group/web'),
        ),
        fake.commands,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Close merge request'), findsOneWidget);
    expect(find.text('Copy reference'), findsOneWidget);
    await tester.tap(find.text('Mark as draft'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['draft=true']);
  });

  testWidgets('a closed MR offers Reopen', (tester) async {
    final fake = _FakeCommands();
    await tester.pumpWidget(
      _overview(
        _mr('closed', const TicketProviderEntity.gitlabItem(closedBy: 'Kan')),
        fake.commands,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Closed by Kan'), findsOneWidget);
    await tester.tap(find.text('Reopen merge request'));
    await tester.pump();
    expect(fake.calls, ['reopen']);
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

  testWidgets('two-pane tabs keep state across switches (loader runs once)', (
    tester,
  ) async {
    var commitCalls = 0;
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
      providerEntity: TicketProviderEntity.gitlabItem(author: 'Thanh'),
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
              commands: _FakeCommands().commands,
              commitsLoader: () async {
                commitCalls++;
                return const Ok(<RepoCommit>[]);
              },
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

    // Lazy: the Commits loader hasn't fired while on the Overview tab.
    expect(commitCalls, 0);

    await tester.tap(find.text('Commits').first);
    await tester.pumpAndSettle();
    expect(commitCalls, 1);

    // Leaving and returning keeps the tab alive → no refetch.
    await tester.tap(find.text('Overview').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commits').first);
    await tester.pumpAndSettle();
    expect(commitCalls, 1);
  });
}
