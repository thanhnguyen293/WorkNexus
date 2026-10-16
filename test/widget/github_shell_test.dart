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
import 'package:work_nexus/tools/github/github_module.dart';
import 'package:work_nexus/tools/github/presentation/nav/github_nav_pane.dart';
import 'package:work_nexus/tools/github/presentation/providers/github_board_providers.dart';
import 'package:work_nexus/tools/github/presentation/sections/github_issues_section.dart';
import 'package:work_nexus/tools/github/presentation/sections/github_pulls_section.dart';
import 'package:work_nexus/tools/github/presentation/widgets/github_board_view.dart';

const _testAccount = Account(
  id: 'acc-gh',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'octocat',
  baseUrl: 'https://github.com',
);

const _testRepo1 = ProviderProject(
  id: 'owner/repo-a',
  name: 'owner/repo-a',
  accountId: 'acc-gh',
);

const _testRepo2 = ProviderProject(
  id: 'owner/repo-b',
  name: 'owner/repo-b',
  accountId: 'acc-gh',
);

Ticket _makePr({
  required String id,
  required String title,
  UnifiedStatus status = UnifiedStatus.inprogress,
  bool draft = false,
  bool merged = false,
  List<String> reviewers = const [],
  List<String> reviewerLogins = const [],
  String repo = 'owner/repo-a',
}) {
  return Ticket(
    id: id,
    accountId: 'acc-gh',
    projectId: repo,
    providerType: ProviderType.github,
    externalKey: id,
    externalType: 'PullRequest',
    title: title,
    body: 'PR body',
    priority: Priority.high,
    status: status,
    providerStatus: merged
        ? 'merged'
        : (status == UnifiedStatus.done ? 'closed' : 'open'),
    sourceHash: 'h_$id',
    providerEntity: TicketProviderEntity.githubItem(
      repo: repo,
      headBranch: 'feature/$id',
      baseBranch: 'main',
      draft: draft,
      merged: merged,
      reviewers: reviewers,
      reviewerLogins: reviewerLogins,
    ),
  );
}

Ticket _makeIssue({
  required String id,
  required String title,
  UnifiedStatus status = UnifiedStatus.todo,
  String repo = 'owner/repo-a',
}) {
  return Ticket(
    id: id,
    accountId: 'acc-gh',
    projectId: repo,
    providerType: ProviderType.github,
    externalKey: id,
    externalType: 'Issue',
    title: title,
    body: 'Issue body',
    priority: Priority.medium,
    status: status,
    providerStatus: status == UnifiedStatus.done ? 'closed' : 'open',
    sourceHash: 'h_$id',
    providerEntity: TicketProviderEntity.githubItem(repo: repo),
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
      githubReposProvider(
        'acc-gh',
      ).overrideWith((ref) => Stream.value([_testRepo1, _testRepo2])),
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
              const ToolLocation(section: SectionId('github.pulls'));
          return Scaffold(body: builder(loc));
        },
      ),
    ),
  );
}

void main() {
  const githubModule = GithubModule();

  final openPr = _makePr(id: '101', title: 'Open PR Alpha');
  final mergedPr = _makePr(id: '102', title: 'Merged PR Beta', merged: true);
  final closedPr = _makePr(
    id: '103',
    title: 'Closed PR Gamma',
    status: UnifiedStatus.done,
  );
  final reviewPr = _makePr(
    id: '104',
    title: 'Review Requested PR',
    reviewers: ['octocat'],
  );
  final otherPr = _makePr(
    id: '105',
    title: 'Other Reviewer PR',
    reviewers: ['someone_else'],
  );
  // A reviewer with a profile name: the name differs from the login.
  final namedReviewPr = _makePr(
    id: '106',
    title: 'Named Reviewer PR',
    reviewers: ['Octo Cat'],
    reviewerLogins: ['octocat'],
  );

  final testTickets = [
    openPr,
    mergedPr,
    closedPr,
    reviewPr,
    otherPr,
    namedReviewPr,
  ];

  group('GitHub Pull Requests Section', () {
    testWidgets('filters by state tabs (Open / Merged / Closed / Board)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gh'),
        locations: {
          'acc-gh': ToolLocation(
            section: SectionId('github.pulls'),
            viewModes: {SectionId('github.pulls'): ViewModeId('open')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: testTickets,
          builder: (loc) =>
              GithubPullsSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      // Open tab: open PRs should be visible
      expect(find.text('Open PR Alpha'), findsOneWidget);
      expect(find.text('Merged PR Beta'), findsNothing);
      expect(find.text('Closed PR Gamma'), findsNothing);

      // Tap Merged tab
      await tester.tap(find.text('Merged'));
      await tester.pumpAndSettle();

      expect(find.text('Merged PR Beta'), findsOneWidget);
      expect(find.text('Open PR Alpha'), findsNothing);
      expect(find.text('Closed PR Gamma'), findsNothing);

      // Tap Closed tab
      await tester.tap(find.text('Closed'));
      await tester.pumpAndSettle();

      expect(find.text('Closed PR Gamma'), findsOneWidget);
      expect(find.text('Open PR Alpha'), findsNothing);
      expect(find.text('Merged PR Beta'), findsNothing);

      // Tap Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.byType(GitHubBoardView), findsOneWidget);
    });

    testWidgets(
      'Review requested chip filters PRs where handle is in reviewers',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const initialNav = AppNavState(
          rail: RailTarget.account('acc-gh'),
          locations: {
            'acc-gh': ToolLocation(
              section: SectionId('github.pulls'),
              viewModes: {SectionId('github.pulls'): ViewModeId('open')},
            ),
          },
        );

        await tester.pumpWidget(
          _buildHarness(
            initialNav: initialNav,
            tickets: testTickets,
            builder: (loc) =>
                GithubPullsSection(account: _testAccount, location: loc),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in All view: open PRs (Alpha, Review, Other) are present
        expect(find.text('Open PR Alpha'), findsOneWidget);
        expect(find.text('Review Requested PR'), findsOneWidget);
        expect(find.text('Other Reviewer PR'), findsOneWidget);

        // Tap "Review requested" chip
        await tester.tap(find.text('Review requested'));
        await tester.pumpAndSettle();

        // Only PRs requesting octocat match — by login, also when the
        // reviewer's display name differs.
        expect(find.text('Review Requested PR'), findsOneWidget);
        expect(find.text('Named Reviewer PR'), findsOneWidget);
        expect(find.text('Open PR Alpha'), findsNothing);
        expect(find.text('Other Reviewer PR'), findsNothing);
      },
    );
  });

  group('GitHub Issues Section', () {
    testWidgets('renders issue list and switches to Board view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final issue1 = _makeIssue(id: '201', title: 'Issue Alpha');
      final issue2 = _makeIssue(id: '202', title: 'Issue Beta');

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gh'),
        locations: {
          'acc-gh': ToolLocation(
            section: SectionId('github.issues'),
            viewModes: {SectionId('github.issues'): ViewModeId('list')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          tickets: [issue1, issue2],
          builder: (loc) =>
              GithubIssuesSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Issue Alpha'), findsOneWidget);
      expect(find.text('Issue Beta'), findsOneWidget);

      // Switch to Board
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.byType(GitHubBoardView), findsOneWidget);
    });
  });

  group('GitHub Nav Pane', () {
    testWidgets('renders feature tabs, quick scopes, and selects repository', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-gh'),
        locations: {'acc-gh': ToolLocation(section: SectionId('github.pulls'))},
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
                child: GithubNavPane(
                  account: _testAccount,
                  location: loc,
                  sections: githubModule.sections,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Feature tabs
      expect(find.text('Pull Requests'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);

      // Quick scopes
      expect(find.text('All repositories'), findsOneWidget);
      expect(find.text('Review requested'), findsOneWidget);

      // Repository row
      expect(find.text('owner/repo-a'), findsOneWidget);

      // Tap repository
      await tester.tap(find.text('owner/repo-a'));
      await tester.pumpAndSettle();

      final locAfterTap = capturedRef.read(appNavProvider).currentLocation;
      expect(locAfterTap?.scopeId, equals('owner/repo-a'));
    });
  });
}
