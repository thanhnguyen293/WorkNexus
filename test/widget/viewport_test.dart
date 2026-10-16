import 'package:flutter/material.dart' hide Viewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/auth_expired_banner.dart';
import 'package:work_nexus/app/shell/section_error_boundary.dart';
import 'package:work_nexus/app/shell/viewport.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/account_sync_status.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/platform/link_router.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_module.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_apps_host.dart';
import 'package:work_nexus/features/translation/presentation/translation_api_providers.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/features/workspace_overview/presentation/pages/overview_page.dart';
import 'package:work_nexus/features/workspace_overview/presentation/providers/overview_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/mini_app_overrides.dart';

class _TestToolModule extends ToolModule {
  const _TestToolModule();

  @override
  ProviderType get providerType => ProviderType.zentao;

  @override
  SectionId get defaultSection => const SectionId('tasks');

  @override
  List<ToolSection> get sections => const [
    ToolSection(
      id: SectionId('tasks'),
      label: _label,
      icon: Icons.check,
      scopeKind: ScopeKind.project,
    ),
  ];

  static String _label(AppL10n l) => 'Tasks';

  @override
  String Function(AppL10n) get roleLabel =>
      (l10n) => 'Project management';

  @override
  Provider<AsyncValue<ToolMetrics>> metrics(Account account) => Provider(
    (ref) => const AsyncValue.data(
      ToolMetrics(primaryCount: 5, primaryLabel: _label),
    ),
  );

  @override
  Widget buildSection(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) {
    return Text('AccountSection:${account.id}:${location.section.value}');
  }
}

const _testAccount = Account(
  id: 'acc_1',
  workspaceId: 'ws_1',
  providerType: ProviderType.zentao,
  handle: 'user1',
  baseUrl: 'https://zentao.example.com',
);

const _testWorkspace = Workspace(
  id: 'ws_1',
  name: 'Test Workspace',
  shortCode: 'TW',
  colorValue: 0xFF2563EB,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.flat,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(body: Viewport()),
      ),
    );
  }

  group('Viewport', () {
    testWidgets(
      'renders active workspace section inside SectionErrorBoundary',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...miniAppShellOverrides(),
            activeWorkspaceProvider.overrideWithValue(_testWorkspace),
            workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
            accountsProvider.overrideWith(
              (ref) => Stream.value([_testAccount]),
            ),
            ticketsProvider.overrideWith(
              (ref) => Stream.value(const <Ticket>[]),
            ),
            toolRegistryProvider.overrideWithValue({
              ProviderType.zentao: const _TestToolModule(),
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildApp(container: container));
        await tester.pumpAndSettle();

        expect(find.byType(OverviewPage), findsOneWidget);
        expect(find.byType(SectionErrorBoundary), findsOneWidget);
      },
    );

    testWidgets(
      'maintains a 3-section LRU cache in IndexedStack and evicts the oldest',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...miniAppShellOverrides(),
            activeWorkspaceProvider.overrideWithValue(_testWorkspace),
            workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
            accountsProvider.overrideWith(
              (ref) => Stream.value([_testAccount]),
            ),
            ticketsProvider.overrideWith(
              (ref) => Stream.value(const <Ticket>[]),
            ),
            openCodeModelsProvider.overrideWith(
              (ref) async => const <String>[],
            ),
            translationApiConfigProvider.overrideWith(
              (ref) async => const Ok(null),
            ),
            toolRegistryProvider.overrideWithValue({
              ProviderType.zentao: const _TestToolModule(),
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildApp(container: container));
        await tester.pumpAndSettle();

        final nav = container.read(appNavProvider.notifier);

        // Section 1: Overview
        var stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 1);
        expect(stack.index, 0);

        // Section 2: Integrations
        nav.selectWorkspaceSection(WorkspaceSection.integrations);
        await tester.pumpAndSettle();

        stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 2);
        expect(stack.index, 1);

        // Section 3: Members
        nav.selectWorkspaceSection(WorkspaceSection.members);
        await tester.pumpAndSettle();

        stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 3);
        expect(stack.index, 2);

        // Section 4: Settings (exceeds max of 3 -> takes the slot of the
        // least recently used: overview)
        nav.selectWorkspaceSection(WorkspaceSection.settings);
        await tester.pumpAndSettle();

        stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 3);
        expect(stack.index, 0);

        // Re-visit Integrations (already cached -> keeps its slot)
        nav.selectWorkspaceSection(WorkspaceSection.integrations);
        await tester.pumpAndSettle();

        stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.children.length, 3);
        expect(stack.index, 1);
      },
    );

    testWidgets('a mini app replaces the section, which stays alive', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...miniAppShellOverrides(),
          activeWorkspaceProvider.overrideWithValue(_testWorkspace),
          workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
          accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
          ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
          toolRegistryProvider.overrideWithValue({
            ProviderType.zentao: const _TestToolModule(),
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container: container));
      await tester.pumpAndSettle();
      expect(find.byType(MiniAppsHost), findsOneWidget);
      final overview = tester.element(find.byType(OverviewPage));

      container.read(appNavProvider.notifier).showMiniApp('m1');
      await tester.pumpAndSettle();
      expect(find.byType(OverviewPage), findsNothing, reason: 'offstage');
      expect(
        identical(
          tester.element(find.byType(OverviewPage, skipOffstage: false)),
          overview,
        ),
        isTrue,
      );

      container.read(appNavProvider.notifier).closeMiniApp();
      await tester.pumpAndSettle();
      expect(find.byType(OverviewPage), findsOneWidget);
    });

    testWidgets('a link to a mini app\'s site opens that mini app', (
      tester,
    ) async {
      const app = MiniApp(
        id: 'm1',
        name: 'Chat',
        url: 'https://chat.example.com',
        position: 0,
      );
      final container = ProviderContainer(
        overrides: [
          ...miniAppShellOverrides(apps: const [app]),
          activeWorkspaceProvider.overrideWithValue(_testWorkspace),
          workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
          accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
          ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
          toolRegistryProvider.overrideWithValue({
            ProviderType.zentao: const _TestToolModule(),
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container: container));
      await tester.pumpAndSettle();

      final opened = linkRouter.route('https://chat.example.com/room/1');
      await tester.pumpAndSettle();

      expect(opened, isTrue);
      expect(container.read(openMiniAppIdProvider), 'm1');
      expect(container.read(miniAppOnScreenProvider), isTrue);
    });

    testWidgets('a cached section survives switching away and back', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...miniAppShellOverrides(),
          activeWorkspaceProvider.overrideWithValue(_testWorkspace),
          workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
          accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
          ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
          toolRegistryProvider.overrideWithValue({
            ProviderType.zentao: const _TestToolModule(),
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container: container));
      await tester.pumpAndSettle();
      Element overview() =>
          tester.element(find.byType(OverviewPage, skipOffstage: false));
      final before = overview();

      final nav = container.read(appNavProvider.notifier)
        ..selectWorkspaceSection(WorkspaceSection.integrations);
      await tester.pumpAndSettle();
      nav.selectWorkspaceSection(WorkspaceSection.overview);
      await tester.pumpAndSettle();

      // The same element means the subtree was kept, not rebuilt.
      expect(identical(overview(), before), isTrue);
    });

    testWidgets('suspends offstage cached sections with TickerMode and Focus', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...miniAppShellOverrides(),
          activeWorkspaceProvider.overrideWithValue(_testWorkspace),
          workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
          accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
          ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
          toolRegistryProvider.overrideWithValue({
            ProviderType.zentao: const _TestToolModule(),
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container: container));
      await tester.pumpAndSettle();

      final nav = container.read(appNavProvider.notifier);
      nav.selectWorkspaceSection(WorkspaceSection.integrations);
      await tester.pumpAndSettle();

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      final tickerModes = stack.children.cast<TickerMode>();
      expect(tickerModes.length, 2);
      // Index 0 (Overview) should be offstage suspended
      expect(tickerModes[0].enabled, isFalse);
      // Index 1 (Integrations) should be active
      expect(tickerModes[1].enabled, isTrue);
    });

    testWidgets(
      'displays AuthExpiredBanner when account sync status is SyncAuthExpired',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...miniAppShellOverrides(),
            activeWorkspaceProvider.overrideWithValue(_testWorkspace),
            workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
            accountsProvider.overrideWith(
              (ref) => Stream.value([_testAccount]),
            ),
            ticketsProvider.overrideWith(
              (ref) => Stream.value(const <Ticket>[]),
            ),
            syncStatusProvider(
              'acc_1',
            ).overrideWith((ref) => Stream.value(const SyncAuthExpired())),
            toolRegistryProvider.overrideWithValue({
              ProviderType.zentao: const _TestToolModule(),
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildApp(container: container));
        await tester.pumpAndSettle();

        final nav = container.read(appNavProvider.notifier);
        nav.selectAccount('acc_1', module: const _TestToolModule());
        await tester.pumpAndSettle();

        expect(find.byType(AuthExpiredBanner), findsOneWidget);
        expect(find.text('Re-authenticate'), findsOneWidget);
        expect(find.text('AccountSection:acc_1:tasks'), findsOneWidget);
      },
    );

    testWidgets(
      'does not show AuthExpiredBanner when sync status is SyncIdle',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            ...miniAppShellOverrides(),
            activeWorkspaceProvider.overrideWithValue(_testWorkspace),
            workspaceAccountsProvider.overrideWith((ref) => [_testAccount]),
            accountsProvider.overrideWith(
              (ref) => Stream.value([_testAccount]),
            ),
            ticketsProvider.overrideWith(
              (ref) => Stream.value(const <Ticket>[]),
            ),
            syncStatusProvider(
              'acc_1',
            ).overrideWith((ref) => Stream.value(const SyncIdle())),
            toolRegistryProvider.overrideWithValue({
              ProviderType.zentao: const _TestToolModule(),
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildApp(container: container));
        await tester.pumpAndSettle();

        final nav = container.read(appNavProvider.notifier);
        nav.selectAccount('acc_1', module: const _TestToolModule());
        await tester.pumpAndSettle();

        expect(find.byType(AuthExpiredBanner), findsNothing);
        expect(find.text('AccountSection:acc_1:tasks'), findsOneWidget);
      },
    );
  });
}
