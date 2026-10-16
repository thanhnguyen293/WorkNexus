import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/tool_registry.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/account_sync_status.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/assigned_work_item.dart';
import 'package:work_nexus/features/workspace_overview/presentation/pages/integrations_page.dart';
import 'package:work_nexus/features/workspace_overview/presentation/pages/members_page.dart';
import 'package:work_nexus/features/workspace_overview/presentation/pages/overview_page.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/assigned_work_list.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/integration_row.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/tool_card.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/workspace_nav_pane.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/zentao_overview_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/dashboard_overrides.dart';

const _testWorkspace = Workspace(
  id: 'ws-1',
  name: 'Mobile App',
  shortCode: 'MA',
  colorValue: 0xFF1D9BF0,
);

const _accountZentao = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'alice',
  baseUrl: 'https://zentao.example.com',
);

const _accountGithub = Account(
  id: 'acc-gh',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'octocat',
  baseUrl: 'https://api.github.com',
);

const _accountGitlab = Account(
  id: 'acc-gl',
  workspaceId: 'ws-1',
  providerType: ProviderType.gitlab,
  handle: 'tanuki',
  baseUrl: 'https://gitlab.com',
);

Ticket _makeTicket({
  required String id,
  required String title,
  required ProviderType provider,
  String? assignee,
}) {
  return Ticket(
    id: id,
    accountId: 'acc-zt',
    projectId: 'p-1',
    providerType: provider,
    externalKey: id,
    externalType: 'task',
    title: title,
    body: 'description',
    providerStatus: 'doing',
    sourceHash: 'hash',
    status: UnifiedStatus.inprogress,
    priority: Priority.high,
    assignee: assignee,
    createdAt: DateTime.utc(2026, 10, 2),
    updatedAt: DateTime.utc(2026, 10, 10),
  );
}

class _TestNavController extends AppNavController {
  AppNavState get currentState => state;
}

Widget _buildTestApp({
  required Widget child,
  List<Account> accounts = const [],
  List<Ticket> tickets = const [],
  Workspace? activeWorkspace = _testWorkspace,
  _TestNavController? navNotifier,
}) {
  return ProviderScope(
    overrides: [
      ...dashboardOverrides(),
      toolRegistryProvider.overrideWithValue(defaultToolRegistry),
      activeWorkspaceProvider.overrideWithValue(activeWorkspace),
      accountsProvider.overrideWith((ref) => Stream.value(accounts)),
      ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
      if (navNotifier != null) appNavProvider.overrideWith(() => navNotifier),
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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workspace Overview', () {
    testWidgets(
      'overview with 0 accounts shows empty state with connect action',
      (tester) async {
        var connectCalled = false;
        await tester.pumpWidget(
          _buildTestApp(
            child: OverviewPage(onConnect: () => connectCalled = true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No tools connected yet'), findsOneWidget);
        expect(
          find.text(
            'Connect a tool to start tracking work across your projects.',
          ),
          findsOneWidget,
        );
        final connectBtn = find.text('Connect a tool');
        expect(connectBtn, findsOneWidget);

        await tester.tap(connectBtn);
        await tester.pumpAndSettle();
        expect(connectCalled, isTrue);
      },
    );

    testWidgets('overview with a ZenTao account renders its card, its '
        'section and assigned work', (tester) async {
      final ticket = _makeTicket(
        id: 'TASK-101',
        title: 'Build auth flow',
        provider: ProviderType.zentao,
        assignee: 'alice',
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: const OverviewPage(),
          accounts: [_accountZentao],
          tickets: [ticket],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(
        find.text('1 tool connected to Mobile App. Pick a tool to work in it.'),
        findsOneWidget,
      );
      // A compact card like every tool, plus its dashboard section.
      expect(find.byType(ToolCard), findsOneWidget);
      expect(find.byType(ZenTaoOverviewSection), findsOneWidget);
      expect(find.text('ZenTao'), findsOneWidget);
      expect(find.text('ZenTao · alice'), findsOneWidget);
      // On the card and in the section's heading.
      expect(find.text('Open ZenTao →'), findsNWidgets(2));
      expect(find.text('Assigned to you'), findsOneWidget);
      // In the assigned work and in the section's My tasks.
      expect(
        find.descendant(
          of: find.byType(AssignedWorkList),
          matching: find.text('Build auth flow'),
        ),
        findsOneWidget,
      );
      expect(find.text('My tasks'), findsOneWidget);
    });

    testWidgets('overview with 3 accounts renders 3 cards and a ZenTao '
        'section', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const OverviewPage(),
          accounts: [_accountZentao, _accountGithub, _accountGitlab],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '3 tools connected to Mobile App. Pick a tool to work in it.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ToolCard), findsNWidgets(3));
      expect(find.byType(ZenTaoOverviewSection), findsOneWidget);
      expect(find.text('ZenTao'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('GitLab'), findsOneWidget);
    });

    testWidgets('tapping an assigned work row calls openTicket', (
      tester,
    ) async {
      const item = AssignedWorkItem(
        ticketId: 't-99',
        provider: ProviderType.zentao,
        displayKey: 'TASK-99',
        title: 'Review landing page copy',
        status: UnifiedStatus.inprogress,
        statusLabel: 'Doing',
        reason: AssignedReason.assignee,
      );

      final navNotifier = _TestNavController();

      await tester.pumpWidget(
        _buildTestApp(
          child: const AssignedWorkList(items: [item]),
          navNotifier: navNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review landing page copy'), findsOneWidget);
      await tester.tap(find.text('Review landing page copy'));
      await tester.pumpAndSettle();

      expect(navNotifier.currentState.openTicketId, 't-99');
    });
  });

  group('Workspace Integrations', () {
    testWidgets('integration row displays authExpired health pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const IntegrationRow(
            account: _accountGitlab,
            syncStatusOverride: AccountSyncStatus.authExpired(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GitLab'), findsOneWidget);
      expect(find.text('Auth expired'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
    });

    testWidgets('info box has text only and no checkbox', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const IntegrationsPage(),
          accounts: [_accountZentao],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who can connect tools'), findsOneWidget);
      expect(
        find.text('Connections are shared by everyone in Mobile App.'),
        findsOneWidget,
      );
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('Workspace Members & Nav Pane', () {
    testWidgets('members page displays ComingSoonView placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const MembersPage()));
      await tester.pumpAndSettle();

      expect(find.text('Members'), findsOneWidget);
      expect(
        find.text(
          'Members are coming soon. Connections are currently shared by everyone using this app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'workspace nav pane displays header, 4 rows, account count, and switches section',
      (tester) async {
        final navNotifier = _TestNavController();

        await tester.pumpWidget(
          _buildTestApp(
            child: const WorkspaceNavPane(),
            accounts: [_accountZentao, _accountGithub],
            navNotifier: navNotifier,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('WORKSPACE / MOBILE APP'), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Integrations'), findsOneWidget);
        expect(find.text('Members'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(
          find.text('2'),
          findsOneWidget,
        ); // 2 accounts in Integrations badge

        await tester.tap(find.text('Integrations'));
        await tester.pumpAndSettle();
        expect(
          navNotifier.currentState.workspaceSection,
          WorkspaceSection.integrations,
        );

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(
          navNotifier.currentState.workspaceSection,
          WorkspaceSection.settings,
        );
      },
    );
  });
}
