import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/contextual_search_field.dart';
import 'package:work_nexus/app/shell/search_results_overlay.dart';
import 'package:work_nexus/app/shell/workspace_switcher_popover.dart';
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
import 'package:work_nexus/l10n/app_localizations.dart';

const _ws1 = Workspace(
  id: 'ws-1',
  name: 'Mobile App',
  shortCode: 'MA',
  colorValue: 0xFF1D9BF0,
);

const _ws2 = Workspace(
  id: 'ws-2',
  name: 'Backend Core',
  shortCode: 'BC',
  colorValue: 0xFF10B981,
);

const _wsEmpty = Workspace(
  id: 'ws-empty',
  name: 'Empty Workspace',
  shortCode: 'EW',
  colorValue: 0xFF8B5CF6,
);

const _accountZt = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'alice',
  baseUrl: 'https://zentao.example.com',
);

const _accountGh = Account(
  id: 'acc-gh',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'octocat',
  baseUrl: 'https://api.github.com',
);

const _accountGl = Account(
  id: 'acc-gl',
  workspaceId: 'ws-2',
  providerType: ProviderType.gitlab,
  handle: 'tanuki',
  baseUrl: 'https://gitlab.com',
);

const _testTicket1 = Ticket(
  id: 't-1',
  accountId: 'acc-zt',
  projectId: 'p-1',
  providerType: ProviderType.zentao,
  externalKey: 'BUG-101',
  title: 'Fix authentication crash',
  body: '',
  priority: Priority.high,
  status: UnifiedStatus.inprogress,
  providerStatus: 'doing',
  sourceHash: 'h1',
);

const _testTicket2 = Ticket(
  id: 't-2',
  accountId: 'acc-gh',
  projectId: 'p-2',
  providerType: ProviderType.github,
  externalKey: 'PR-42',
  title: 'Add login button animation',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'open',
  sourceHash: 'h2',
);

Widget _buildTestWidget({
  required Widget child,
  String activeWsId = 'ws-1',
  List<Workspace> workspaces = const [_ws1, _ws2, _wsEmpty],
  List<Account> accounts = const [_accountZt, _accountGh, _accountGl],
  List<Ticket> tickets = const [_testTicket1, _testTicket2],
  _TestNavController? navNotifier,
}) {
  return ProviderScope(
    overrides: [
      workspacesProvider.overrideWith((ref) => Stream.value(workspaces)),
      accountsProvider.overrideWith((ref) => Stream.value(accounts)),
      ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
      activeWorkspaceIdProvider.overrideWith((ref) => activeWsId),
      activeWorkspaceProvider.overrideWithValue(
        workspaces.where((w) => w.id == activeWsId).firstOrNull ?? _ws1,
      ),
      toolRegistryProvider.overrideWithValue(defaultToolRegistry),
      if (navNotifier != null) appNavProvider.overrideWith(() => navNotifier),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.dark,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

class _TestNavController extends AppNavController {
  _TestNavController([AppNavState? initial]) : _initial = initial;
  final AppNavState? _initial;

  @override
  AppNavState build() => _initial ?? super.build();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkspaceSwitcherPopover', () {
    testWidgets('renders all workspaces and shows tool subtitles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(child: const WorkspaceSwitcherPopover()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobile App'), findsOneWidget);
      expect(find.text('Backend Core'), findsOneWidget);
      expect(find.text('Empty Workspace'), findsOneWidget);

      // Mobile App has ZenTao and GitHub
      expect(find.text('ZenTao · GitHub'), findsOneWidget);
      // Backend Core has GitLab
      expect(find.text('GitLab'), findsOneWidget);
      // Empty Workspace has no connected tools
      expect(find.text('No tools connected yet'), findsOneWidget);
    });

    testWidgets('filters workspace list by typing in search field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(child: const WorkspaceSwitcherPopover()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobile App'), findsOneWidget);
      expect(find.text('Backend Core'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Backend');
      await tester.pumpAndSettle();

      expect(find.text('Backend Core'), findsOneWidget);
      expect(find.text('Mobile App'), findsNothing);
      expect(find.text('Empty Workspace'), findsNothing);
    });

    testWidgets('keyboard navigation selects workspace with Enter', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        _buildTestWidget(
          child: WorkspaceSwitcherPopover(onClose: () => closed = true),
        ),
      );
      await tester.pumpAndSettle();

      // Press down arrow to highlight second item (Backend Core)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets(
      'workspace switch resets rail when active account is not in new workspace',
      (tester) async {
        // Start on acc-zt (which belongs to ws-1)
        const initialNav = AppNavState(
          rail: AccountTarget('acc-zt'),
          locations: {'acc-zt': ToolLocation(section: SectionId('tasks'))},
        );

        await tester.pumpWidget(
          _buildTestWidget(
            child: const WorkspaceSwitcherPopover(),
            navNotifier: _TestNavController(initialNav),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceSwitcherPopover)),
        );
        expect(
          container.read(appNavProvider).rail,
          const AccountTarget('acc-zt'),
        );

        // Tap Empty Workspace (ws-empty)
        await tester.tap(find.text('Empty Workspace'));
        await tester.pumpAndSettle();

        // Since acc-zt is not in ws-empty, rail resets to WorkspaceTarget (specs S2.2)
        expect(container.read(appNavProvider).rail, const WorkspaceTarget());
        expect(container.read(activeWorkspaceIdProvider), 'ws-empty');
      },
    );
  });

  group('ContextualSearchField', () {
    testWidgets('displays workspace contextual placeholder', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(child: const ContextualSearchField()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search tasks, bugs, PRs, MRs…'), findsOneWidget);
    });

    testWidgets('debounces query and shows search results overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(child: const ContextualSearchField()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BUG-101');
      // Before debounce time
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SearchResultsOverlay), findsNothing);

      // Advance past 150ms debounce
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsOverlay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SearchResultsOverlay),
          matching: find.text('BUG-101'),
        ),
        findsOneWidget,
      );
      expect(find.text('Fix authentication crash'), findsOneWidget);
    });

    testWidgets('escape key clears search field and closes overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(child: const ContextualSearchField()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BUG');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsOverlay), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SearchResultsOverlay), findsNothing);
    });
  });
}
