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
import 'package:work_nexus/features/workspace_overview/presentation/widgets/dashboard_card.dart';
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
  executions: [
    for (var i = 1; i <= 6; i++)
      DashboardExecution(
        id: '$i',
        name: 'Sprint $i',
        status: i <= 2 ? 'doing' : 'wait',
        progress: 40,
        end: DateTime.now().add(Duration(days: i)),
      ),
  ],
  executionTotal: 6,
  activities: [
    for (var i = 1; i <= 7; i++)
      DashboardActivity(
        id: '$i',
        actor: 'Bob',
        action: 'resolved',
        objectType: 'bug',
        objectId: '$i',
        objectName: 'Event $i',
      ),
  ],
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<Account> accounts,
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 4000);
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
              // More bugs than tasks: the cards' natural heights differ.
              for (var i = 2; i <= 5; i++) _ticket('$i', 'Bug', 'Bug no $i'),
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
    return ProviderScope.containerOf(tester.element(find.byType(OverviewPage)));
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(DashboardCard));

  Finder queue(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DashboardQueue),
  );

  testWidgets('the tool cards fill the row, ZenTao included; its section '
      'follows, then the assigned work', (tester) async {
    await pump(tester, accounts: [_zentao, _github]);

    final row = tester.getRect(find.byType(AssignedWorkList));
    final cards = find.byType(ToolCard);
    expect(cards, findsNWidgets(2));
    // Two tools, two equal columns spanning the content width.
    expect(tester.getRect(cards.first).left, closeTo(row.left, 1));
    expect(tester.getRect(cards.last).right, closeTo(row.right, 1));
    expect(
      tester.getSize(cards.first).width,
      closeTo(tester.getSize(cards.last).width, 1),
    );
    // ZenTao's card keeps the account-wide numbers.
    expect(
      find.descendant(of: cards.first, matching: find.text('Open tasks')),
      findsOneWidget,
    );

    final section = tester.getRect(find.byType(ZenTaoOverviewSection));
    expect(section.top, greaterThan(tester.getRect(cards.first).bottom));
    expect(row.top, greaterThan(section.bottom));
    expect(find.text('ZenTao · alice'), findsOneWidget);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('My bugs'), findsOneWidget);
  });

  testWidgets('a single tool fills the row', (tester) async {
    await pump(tester, accounts: [_github]);

    final row = tester.getRect(find.byType(AssignedWorkList));
    final card = tester.getRect(find.byType(ToolCard));
    expect(card.width, closeTo(row.width, 1));
  });

  testWidgets('"Show all" sits at the trailing edge of its card header and '
      'My tasks matches My bugs in height', (tester) async {
    await pump(tester, accounts: [_zentao, _github]);

    for (final title in ['My tasks', 'My bugs']) {
      final box = tester.getRect(queue(title));
      final showAll = tester.getRect(
        find.descendant(of: queue(title), matching: find.text('Show all')),
      );
      expect(box.right - showAll.right, lessThan(box.width * 0.1));
    }
    expect(
      tester.getSize(queue('My tasks')).height,
      tester.getSize(queue('My bugs')).height,
    );
    expect(
      tester.getTopLeft(queue('My tasks')).dy,
      tester.getTopLeft(queue('My bugs')).dy,
    );
  });

  testWidgets('executions and activity are capped, side by side at one '
      'height; "Show all" opens the Executions tab', (tester) async {
    final container = await pump(tester, accounts: [_zentao]);

    // Running and ending soonest first: 3 of the 6.
    expect(find.text('Sprint 1'), findsOneWidget);
    expect(find.text('Sprint 2'), findsOneWidget);
    expect(find.text('Sprint 3'), findsOneWidget);
    expect(find.text('Sprint 4'), findsNothing);
    expect(find.text('Event 5'), findsOneWidget);
    expect(find.text('Event 6'), findsNothing);
    expect(
      tester.getSize(card('Executions')).height,
      tester.getSize(card('Recent activity')).height,
    );

    await tester.tap(
      find.descendant(of: card('Executions'), matching: find.text('Show all')),
    );
    await tester.pump();
    final nav = container.read(appNavProvider);
    expect(nav.rail, const RailTarget.account('zt-1'));
    expect(nav.locations['zt-1']?.section.value, 'zentao.sprints');
  });

  testWidgets('without a ZenTao account there is no section', (tester) async {
    await pump(tester, accounts: [_github, _gitlab]);

    expect(find.byType(ZenTaoOverviewSection), findsNothing);
    expect(find.text('My tasks'), findsNothing);
    expect(find.byType(ToolCard), findsNWidgets(2));
    expect(find.byType(AssignedWorkList), findsOneWidget);
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
    expect(find.byType(ToolCard), findsNWidgets(2));
  });

  for (final width in [1400.0, 900.0, 420.0]) {
    testWidgets('no overflow at ${width.round()}px', (tester) async {
      await pump(tester, accounts: [_zentao, _github, _gitlab], width: width);

      expect(tester.takeException(), isNull);
      expect(find.text('Sprint 1'), findsOneWidget);
      if (width < 900) {
        // Narrow: every card stacks.
        expect(
          tester.getTopLeft(queue('My bugs')).dy,
          greaterThan(tester.getBottomLeft(queue('My tasks')).dy - 1),
        );
      }
    });
  }

  testWidgets('"Show all" opens the full list in the Overview\'s place and '
      'back returns to it', (tester) async {
    await pump(tester, accounts: [_zentao, _github]);

    await tester.tap(
      find.descendant(of: queue('My bugs'), matching: find.text('Show all')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DashboardWorkView), findsOneWidget);
    expect(find.byType(ZenTaoOverviewSection), findsNothing);
    expect(find.text('Bug no 2'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardWorkView), findsNothing);
    expect(find.byType(ZenTaoOverviewSection), findsOneWidget);
  });
}
