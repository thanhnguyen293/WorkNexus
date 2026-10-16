import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/pinned_execution.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/shell_pane/sidebar_primitives.dart';
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_projects_scope_list.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';

const _account = Account(
  id: 'zt',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'me',
);

const _executions = [
  ProviderExecution(id: '7', name: 'Sprint 7', projectId: '1', accountId: 'zt'),
  ProviderExecution(id: '8', name: 'Sprint 8', projectId: '1', accountId: 'zt'),
];

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    final container = ProviderContainer(
      overrides: [
        zentaoProjectsProvider('zt').overrideWith(
          (ref) => Stream.value(const [
            ProviderProject(id: '1', name: 'Wallet', accountId: 'zt'),
          ]),
        ),
        zentaoExecutionsProvider((
          accountId: 'zt',
          projectId: '1',
        )).overrideWith((ref) async => _executions),
        ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
        initialAppSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    container.read(appNavProvider.notifier)
      ..selectAccount('zt')
      ..selectSection(const SectionId('zentao.tasks'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: ZentaoProjectsScopeList(
                account: _account,
                location: ToolLocation(section: SectionId('zentao.tasks')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a project only opens and closes; it has no pin', (tester) async {
    final container = await pump(tester);
    expect(find.byType(SidebarPinButton), findsNothing);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Sprint 7'), findsOneWidget);
    expect(container.read(currentToolLocationProvider)?.scopeId, isNull);
    expect(container.read(selectedZenTaoExecutionProvider), isNull);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Sprint 7'), findsNothing);
  });

  testWidgets('tapping an execution opens its board', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sprint 8'));
    await tester.pumpAndSettle();

    expect(container.read(currentToolLocationProvider)?.scopeId, '8');
    expect(container.read(selectedZenTaoExecutionProvider)?.executionId, '8');
  });

  testWidgets('pinned holds executions, lifted out of the tree', (
    tester,
  ) async {
    await pump(
      tester,
      settings: const AppSettings(
        pinnedExecutions: [
          PinnedExecution(
            accountId: 'zt',
            projectId: '1',
            executionId: '7',
            name: 'Sprint 7',
          ),
        ],
      ),
    );

    expect(find.text('Sprint 7'), findsOneWidget);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // Still once: the tree leaves the pinned one out.
    expect(find.text('Sprint 7'), findsOneWidget);
    expect(find.text('Sprint 8'), findsOneWidget);
  });
}
