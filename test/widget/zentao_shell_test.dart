import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_nav_pane.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/sections/zentao_bugs_section.dart';
import 'package:work_nexus/tools/zentao/presentation/sections/zentao_tasks_section.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_bug_board_view.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_bug_table_view.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_task_board_view.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_task_table_view.dart';
import 'package:work_nexus/tools/zentao/zentao_module.dart';

const _testAccount = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'dev_zt',
  baseUrl: 'https://zentao.corp.net',
);

const _testProject = ProviderProject(
  id: 'proj-1',
  name: 'Alpha Project',
  accountId: 'acc-zt',
);

const _testProduct = ProviderProduct(
  id: 'prod-1',
  name: 'Mobile App',
  accountId: 'acc-zt',
);

const _testTask = Ticket(
  id: 'zt:task:101',
  accountId: 'acc-zt',
  projectId: 'proj-1',
  providerType: ProviderType.zentao,
  externalKey: '101',
  externalType: 'task',
  title: 'Setup build pipeline',
  body: 'Configure pipeline',
  priority: Priority.high,
  status: UnifiedStatus.inprogress,
  providerStatus: 'doing',
  sourceHash: 'h1',
  assignee: 'Alice',
);

class _TestNavNotifier extends AppNavController {
  _TestNavNotifier(this._initial);
  final AppNavState _initial;

  @override
  AppNavState build() => _initial;
}

/// The execution the tasks board shows (ZenTao lists tasks per execution).
class _ExecutionSelection extends SelectedZenTaoExecution {
  @override
  ZenTaoExecutionSelection? build() => const ZenTaoExecutionSelection(
    accountId: 'acc-zt',
    projectId: 'proj-1',
    executionId: 'exec-1',
    executionName: 'Sprint 1',
  );
}

class _TicketsController extends ScopedTicketsOverrideController {
  _TicketsController(this._initial);
  final List<Ticket> _initial;

  @override
  List<Ticket>? build() => _initial;
}

Widget _buildHarness({
  required AppNavState initialNav,
  required Widget Function(ToolLocation location) builder,
}) {
  return ProviderScope(
    overrides: [
      openTicketIdProvider.overrideWithValue(null),
      accountsProvider.overrideWith((ref) => Stream.value([_testAccount])),
      zentaoProjectsProvider(
        'acc-zt',
      ).overrideWith((ref) => Stream.value([_testProject])),
      zentaoProductsProvider(
        'acc-zt',
      ).overrideWith((ref) => Stream.value([_testProduct])),
      scopedTicketsOverrideProvider.overrideWith(
        () => _TicketsController([_testTask]),
      ),
      appNavProvider.overrideWith(() => _TestNavNotifier(initialNav)),
      selectedZenTaoExecutionProvider.overrideWith(_ExecutionSelection.new),
      zentaoExecutionsProvider((
        accountId: 'acc-zt',
        projectId: 'proj-1',
      )).overrideWith(
        (ref) async => const [
          ProviderExecution(
            id: 'exec-1',
            name: 'Sprint 1',
            projectId: 'proj-1',
            accountId: 'acc-zt',
          ),
        ],
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
      home: Consumer(
        builder: (context, ref, child) {
          final nav = ref.watch(appNavProvider);
          final loc =
              nav.currentLocation ??
              const ToolLocation(section: SectionId('zentao.tasks'));
          return Scaffold(body: builder(loc));
        },
      ),
    ),
  );
}

void main() {
  const zentaoModule = ZentaoModule();

  group('ZenTao Tasks Section View Modes', () {
    testWidgets('toggles between List and Board mode', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-zt'),
        locations: {
          'acc-zt': ToolLocation(
            section: SectionId('zentao.tasks'),
            scopeId: 'exec-1',
            viewModes: {SectionId('zentao.tasks'): ViewModeId('list')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          builder: (loc) =>
              ZentaoTasksSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in List mode
      expect(find.byType(ZenTaoTaskTableView), findsOneWidget);
      expect(find.byType(ZenTaoTaskBoardView), findsNothing);

      // Tap Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      // Now in Board mode
      expect(find.byType(ZenTaoTaskBoardView), findsOneWidget);
      expect(find.byType(ZenTaoTaskTableView), findsNothing);

      // Tap List tab to switch back
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.byType(ZenTaoTaskTableView), findsOneWidget);
    });

    testWidgets('offers Board and List only; a calendar view left from '
        'before shows the board', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-zt'),
        locations: {
          'acc-zt': ToolLocation(
            section: SectionId('zentao.tasks'),
            scopeId: 'exec-1',
            viewModes: {SectionId('zentao.tasks'): ViewModeId('calendar')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          builder: (loc) =>
              ZentaoTasksSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZenTaoTaskBoardView), findsOneWidget);
      expect(find.text('Calendar'), findsNothing);
      expect(find.text('Gantt'), findsNothing);
    });
  });

  group('ZenTao Bugs Section View Modes', () {
    testWidgets('renders Board view and toggles to List view', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const initialNav = AppNavState(
        rail: RailTarget.account('acc-zt'),
        locations: {
          'acc-zt': ToolLocation(
            section: SectionId('zentao.bugs'),
            viewModes: {SectionId('zentao.bugs'): ViewModeId('board')},
          ),
        },
      );

      await tester.pumpWidget(
        _buildHarness(
          initialNav: initialNav,
          builder: (loc) =>
              ZentaoBugsSection(account: _testAccount, location: loc),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ZenTaoBugBoardView), findsOneWidget);

      // Tap List mode tab
      await tester.tap(find.text('List'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ZenTaoBugTableView), findsOneWidget);
    });
  });

  group('ZenTao Nav Pane', () {
    testWidgets(
      'renders sections, no quick scopes; a project opens, an execution is picked',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const initialNav = AppNavState(
          rail: RailTarget.account('acc-zt'),
          locations: {
            'acc-zt': ToolLocation(section: SectionId('zentao.tasks')),
          },
        );

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          _buildHarness(
            initialNav: initialNav,
            builder: (loc) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return SizedBox(
                  width: 260,
                  child: ZentaoNavPane(
                    account: _testAccount,
                    location: loc,
                    sections: zentaoModule.sections,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify sections in feature tab strip
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Bugs'), findsOneWidget);

        // No quick scopes: ZenTao has no account-wide task list, and the
        // board's own chip narrows to your tasks.
        expect(find.text('All projects'), findsNothing);
        expect(find.text('Assigned to me'), findsNothing);

        // Verify project row
        expect(find.text('Alpha Project'), findsOneWidget);

        // A project only opens: it is never the board's scope.
        await tester.tap(find.text('Alpha Project'));
        await tester.pumpAndSettle();
        expect(
          capturedRef.read(appNavProvider).currentLocation?.scopeId,
          isNull,
        );

        // Its executions are what opens a board.
        await tester.tap(find.text('Sprint 1'));
        await tester.pumpAndSettle();
        expect(
          capturedRef.read(appNavProvider).currentLocation?.scopeId,
          equals('exec-1'),
        );
      },
    );
  });
}
