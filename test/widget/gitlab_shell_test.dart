import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/gitlab/gitlab_module.dart';
import 'package:work_nexus/tools/gitlab/presentation/nav/gitlab_nav_pane.dart';
import 'package:work_nexus/tools/gitlab/presentation/providers/gitlab_board_providers.dart';
import 'package:work_nexus/tools/gitlab/presentation/sections/gitlab_issues_section.dart';
import 'package:work_nexus/tools/gitlab/presentation/sections/gitlab_mrs_section.dart';
import 'package:work_nexus/tools/gitlab/presentation/widgets/gitlab_board_view.dart';

const _testAccount = Account(
  id: 'acc-gl',
  workspaceId: 'ws-1',
  providerType: ProviderType.gitlab,
  handle: 'tanuki',
  baseUrl: 'https://gitlab.com',
);

const _testProject1 = ProviderProject(
  id: 'group/project-a',
  name: 'Project Alpha',
  accountId: 'acc-gl',
);

const _testProject2 = ProviderProject(
  id: 'group/project-b',
  name: 'Project Beta',
  accountId: 'acc-gl',
);

Ticket _makeMr({
  required String id,
  required String title,
  UnifiedStatus status = UnifiedStatus.inprogress,
  bool draft = false,
  bool merged = false,
  List<String> reviewers = const [],
  List<String> assignees = const [],
  String project = 'group/project-a',
}) {
  final effectiveStatus = merged ? UnifiedStatus.done : status;
  return Ticket(
    id: id,
    accountId: 'acc-gl',
    projectId: project,
    providerType: ProviderType.gitlab,
    externalKey: id,
    externalType: 'MergeRequest',
    title: title,
    body: 'MR body',
    priority: Priority.high,
    status: effectiveStatus,
    providerStatus: merged
        ? 'merged'
        : (effectiveStatus == UnifiedStatus.done ? 'closed' : 'opened'),
    sourceHash: 'h_$id',
    providerEntity: TicketProviderEntity.gitlabItem(
      projectPath: project,
      draft: draft,
      reviewers: reviewers,
      assignees: assignees,
      // The sync stores assignee logins beside their display names; "mine"
      // is matched on the login.
      assigneeLogins: assignees,
    ),
  );
}

Ticket _makeIssue({
  required String id,
  required String title,
  UnifiedStatus status = UnifiedStatus.todo,
  String project = 'group/project-a',
}) {
  return Ticket(
    id: id,
    accountId: 'acc-gl',
    projectId: project,
    providerType: ProviderType.gitlab,
    externalKey: id,
    externalType: 'Issue',
    title: title,
    body: 'Issue body',
    priority: Priority.medium,
    status: status,
    providerStatus: status == UnifiedStatus.done ? 'closed' : 'opened',
    sourceHash: 'h_$id',
    providerEntity: TicketProviderEntity.gitlabItem(projectPath: project),
  );
}

class _TestNavNotifier extends AppNavController {
  _TestNavNotifier(this._initial);
  final AppNavState _initial;

  @override
  AppNavState build() => _initial;
}

Widget _buildHarness({
  required AppNavState initialNav,
  required List<Ticket> tickets,
  required Widget Function(ToolLocation location) builder,
}) {
  return ProviderScope(
    overrides: [
      openTicketIdProvider.overrideWithValue(null),
      accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
      ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
      gitlabProjectsProvider(
        'acc-gl',
      ).overrideWith((ref) => Stream.value([_testProject1, _testProject2])),
      appNavProvider.overrideWith(() => _TestNavNotifier(initialNav)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final nav = ref.watch(appNavProvider);
          final loc =
              nav.currentLocation ??
              const ToolLocation(section: SectionId('gitlab.mrs'));
          return Scaffold(body: builder(loc));
        },
      ),
    ),
  );
}

void main() {
  const gitlabModule = GitlabModule();

  final openMr = _makeMr(id: '101', title: 'Open MR Alpha');
  final mergedMr = _makeMr(id: '102', title: 'Merged MR Beta', merged: true);
  final closedMr = _makeMr(
    id: '103',
    title: 'Closed MR Gamma',
    status: UnifiedStatus.done,
  );
  final draftMr = _makeMr(id: '104', title: 'Draft MR Delta', draft: true);
  final reviewMr = _makeMr(
    id: '105',
    title: 'In Review MR Epsilon',
    reviewers: ['tanuki'],
  );
  final assignedMr = _makeMr(
    id: '106',
    title: 'Assigned MR Zeta',
    assignees: ['tanuki'],
  );

  final testTickets = [
    openMr,
    mergedMr,
    closedMr,
    draftMr,
    reviewMr,
    assignedMr,
  ];

  group('GitLab Merge Requests Section', () {
    testWidgets('filters by state tabs (Open / Merged / Closed / Board)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gl'),
        locations: {
          'acc-gl': ToolLocation(
            section: SectionId('gitlab.mrs'),
            viewModes: {SectionId('gitlab.mrs'): ViewModeId('open')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: testTickets,
          builder: (loc) =>
              GitlabMrsSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      // Open tab: open MRs should be visible
      expect(find.text('Open MR Alpha'), findsOneWidget);
      expect(find.text('Draft MR Delta'), findsOneWidget);
      expect(find.text('Merged MR Beta'), findsNothing);
      expect(find.text('Closed MR Gamma'), findsNothing);

      // Tap Merged tab
      await tester.tap(find.text('Merged'));
      await tester.pumpAndSettle();

      expect(find.text('Merged MR Beta'), findsOneWidget);
      expect(find.text('Open MR Alpha'), findsNothing);
      expect(find.text('Closed MR Gamma'), findsNothing);

      // Tap Closed tab
      await tester.tap(find.text('Closed'));
      await tester.pumpAndSettle();

      expect(find.text('Closed MR Gamma'), findsOneWidget);
      expect(find.text('Open MR Alpha'), findsNothing);
      expect(find.text('Merged MR Beta'), findsNothing);

      // Tap Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.byType(GitLabBoardView), findsOneWidget);
    });

    testWidgets('chip filtering works for Draft, In review, Assigned to me', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gl'),
        locations: {
          'acc-gl': ToolLocation(
            section: SectionId('gitlab.mrs'),
            viewModes: {SectionId('gitlab.mrs'): ViewModeId('open')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: testTickets,
          builder: (loc) =>
              GitlabMrsSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Draft" chip
      await tester.tap(find.text('Draft').first);
      await tester.pumpAndSettle();

      expect(find.text('Draft MR Delta'), findsOneWidget);
      expect(find.text('Open MR Alpha'), findsNothing);

      // Tap "In review" chip
      await tester.tap(find.text('In review'));
      await tester.pumpAndSettle();

      expect(find.text('In Review MR Epsilon'), findsOneWidget);
      expect(find.text('Draft MR Delta'), findsNothing);

      // Tap "Assigned to me" chip
      await tester.tap(find.text('Assigned to me'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned MR Zeta'), findsOneWidget);
      expect(find.text('In Review MR Epsilon'), findsNothing);
    });
  });

  group('GitLab Issues Section', () {
    testWidgets('renders issue list and switches to Board view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final issue1 = _makeIssue(id: '201', title: 'Issue Alpha');
      final issue2 = _makeIssue(id: '202', title: 'Issue Beta');

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gl'),
        locations: {
          'acc-gl': ToolLocation(
            section: SectionId('gitlab.issues'),
            viewModes: {SectionId('gitlab.issues'): ViewModeId('list')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: [issue1, issue2],
          builder: (loc) =>
              GitlabIssuesSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Issue Alpha'), findsOneWidget);
      expect(find.text('Issue Beta'), findsOneWidget);

      // Switch to Board
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.byType(GitLabBoardView), findsOneWidget);
    });
  });

  group('GitLab Nav Pane', () {
    testWidgets('renders feature tabs, quick scopes, and selects project', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gl'),
        locations: {'acc-gl': ToolLocation(section: SectionId('gitlab.mrs'))},
      );

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: testTickets,
          builder: (loc) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return SizedBox(
                width: 260,
                child: GitlabNavPane(
                  account: _testAccount,
                  location: loc,
                  sections: gitlabModule.sections,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Feature tabs
      expect(find.text('Merge Requests'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);

      // Filter placeholder
      expect(find.text('Filter 2 projects…'), findsOneWidget);

      // Quick scopes
      expect(find.text('All projects'), findsOneWidget);
      expect(find.text('Assigned to me'), findsOneWidget);

      // Project row
      expect(find.text('Project Alpha'), findsOneWidget);

      // Tap project
      await tester.tap(find.text('Project Alpha'));
      await tester.pumpAndSettle();

      final locAfterTap = capturedRef.read(appNavProvider).currentLocation;
      expect(locAfterTap?.scopeId, equals('group/project-a'));
    });

    testWidgets('renders recent scope group when recentScopeIds present', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gl'),
        locations: {
          'acc-gl': ToolLocation(
            section: SectionId('gitlab.mrs'),
            recentScopeIds: ['group/project-b'],
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: testTickets,
          builder: (loc) => SizedBox(
            width: 260,
            child: GitlabNavPane(
              account: _testAccount,
              location: loc,
              sections: gitlabModule.sections,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Project Beta'), findsWidgets);
    });
  });
}
