import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/tool_registry.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/dashboard_activity.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/dashboard_execution.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/dashboard_profile.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/zentao_dashboard.dart';
import 'package:work_nexus/features/workspace_overview/presentation/pages/overview_page.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/assigned_work_list.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/dashboard_queue.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/dashboard_work_view.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/tool_card.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/zentao_overview_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/dashboard_overrides.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Mobile App',
  shortCode: 'MA',
  colorValue: 0xFF1D9BF0,
);

Account _account(String id, ProviderType type, {String host = 'example'}) =>
    Account(
      id: id,
      workspaceId: 'ws-1',
      providerType: type,
      handle: 'alice',
      baseUrl: 'https://$host.com',
    );

final _zentao = _account('zt-1', ProviderType.zentao, host: 'zentao');
final _github = _account('gh', ProviderType.github);
final _gitlab = _account('gl', ProviderType.gitlab);

Ticket _ticket(String id, String type, String title) => Ticket(
  id: 'zt-1:${type.toLowerCase()}:$id',
  accountId: 'zt-1',
  projectId: 'zt-1:p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: type,
  title: title,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: '',
  assignee: 'alice',
);

ZenTaoDashboard _dashboard(String accountId) => ZenTaoDashboard(
  accountId: accountId,
  profile: const DashboardProfile(account: 'alice', realname: 'Alice Tran'),
  fetchedAt: DateTime.now(),
  executions: const [
    DashboardExecution(id: '7', name: 'Sprint 12', status: 'doing'),
  ],
  executionTotal: 1,
  activities: const [
    DashboardActivity(
      id: '1',
      actor: 'Bob',
      action: 'resolved',
      objectType: 'bug',
      objectId: '2',
      objectName: 'Crash on launch',
    ),
  ],
);

void main() {
  Future<FakeDashboardRepository> pump(
    WidgetTester tester, {
    required List<Account> accounts,
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeDashboardRepository({
      for (final a in accounts) a.id: _dashboard(a.id),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...dashboardOverrides(repository: repository),
          toolRegistryProvider.overrideWithValue(defaultToolRegistry),
          activeWorkspaceProvider.overrideWithValue(_workspace),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          ticketsProvider.overrideWith(
            (ref) => Stream.value([
              _ticket('1', 'Task', 'Wire up push'),
              _ticket('2', 'Bug', 'Push opens nothing'),
            ]),
          ),
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
          home: const Scaffold(body: OverviewPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Finder queue(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DashboardQueue),
  );

  testWidgets('a ZenTao account gets a full-width section with its dashboard '
      'between the compact cards and the assigned work', (tester) async {
    final repository = await pump(
      tester,
      accounts: [_zentao, _github, _gitlab],
    );

    expect(find.byType(ZenTaoOverviewSection), findsOneWidget);
    // The card's header lives on in the section.
    expect(find.text('Open ZenTao →'), findsOneWidget);
    expect(find.text('Open tasks'), findsOneWidget);
    // Its dashboard: My tasks, My bugs, executions and activity.
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('My bugs'), findsOneWidget);
    expect(find.text('Wire up push'), findsWidgets);
    expect(find.text('Sprint 12'), findsOneWidget);
    expect(find.text('Crash on launch'), findsOneWidget);
    // GitHub and GitLab stay compact cards.
    expect(find.byType(ToolCard), findsNWidgets(2));
    expect(find.text('Open GitHub →'), findsOneWidget);
    expect(find.text('Open GitLab →'), findsOneWidget);

    final section = tester.getRect(find.byType(ZenTaoOverviewSection));
    expect(
      section.top,
      greaterThan(tester.getRect(find.byType(ToolCard).first).bottom),
    );
    expect(
      tester.getRect(find.byType(AssignedWorkList)).top,
      greaterThan(section.bottom),
    );
    // Wide: My tasks beside My bugs.
    expect(
      tester.getTopLeft(queue('My bugs')).dy,
      tester.getTopLeft(queue('My tasks')).dy,
    );
    // The stored snapshot is fresh, so it is not fetched again; the assigned
    // work syncs once.
    expect(repository.refreshCalls, 0);
    expect(repository.syncCalls, 1);
  });

  testWidgets('without a ZenTao account there is no section', (tester) async {
    final repository = await pump(tester, accounts: [_github, _gitlab]);

    expect(find.byType(ZenTaoOverviewSection), findsNothing);
    expect(find.text('My tasks'), findsNothing);
    expect(find.byType(ToolCard), findsNWidgets(2));
    expect(find.byType(AssignedWorkList), findsOneWidget);
    expect(repository.syncCalls, 0);
  });

  testWidgets('each ZenTao account gets its own section', (tester) async {
    await pump(
      tester,
      accounts: [
        _zentao,
        _account('zt-2', ProviderType.zentao, host: 'other'),
      ],
    );

    expect(find.byType(ZenTaoOverviewSection), findsNWidgets(2));
    expect(find.byType(ToolCard), findsNothing);
  });

  testWidgets('narrow: the cards stack without overflowing', (tester) async {
    await pump(tester, accounts: [_zentao, _github], width: 480);

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(queue('My bugs')).dy,
      greaterThan(tester.getBottomLeft(queue('My tasks')).dy - 1),
    );
    expect(find.text('Sprint 12'), findsOneWidget);
  });

  testWidgets('"Show all" opens the full list in the Overview\'s place and '
      'back returns to it', (tester) async {
    await pump(tester, accounts: [_zentao, _github]);

    await tester.tap(
      find.descendant(of: queue('My bugs'), matching: find.text('Show all')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardWorkView), findsOneWidget);
    expect(find.byType(ZenTaoOverviewSection), findsNothing);
    expect(find.text('Push opens nothing'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardWorkView), findsNothing);
    expect(find.byType(ZenTaoOverviewSection), findsOneWidget);
    expect(find.byType(ToolCard), findsOneWidget);
  });
}
