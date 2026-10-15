import 'package:flutter/material.dart' hide Viewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/app.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/app/shell/app_nav_rail.dart';
import 'package:work_nexus/app/shell/rail_workspace_button.dart';
import 'package:work_nexus/app/shell/title_bar.dart';
import 'package:work_nexus/app/shell/viewport.dart';
import 'package:work_nexus/app/tool_registry.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/platform/desktop_notifier.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/download_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/install_update.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_controller.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_state.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/connections/presentation/providers/zentao_profile_startup_controller.dart';
import 'package:work_nexus/features/notifications/presentation/providers/notification_providers.dart';
import 'package:work_nexus/features/workspace_overview/presentation/widgets/workspace_nav_pane.dart';

import '../support/di_test_harness.dart';

class _FakeUpdateRepo implements UpdateRepository {
  @override
  Future<String> currentVersion() async => '1.0.0';

  @override
  Future<Result<UpdateVersionSnapshot?>> fetchLatestStableRelease() async =>
      const Ok(null);

  @override
  Future<Result<String>> download(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  }) async => const Ok('');

  @override
  Future<Result<void>> install(String stagedPath) async => const Ok(null);
}

class _MockUpdateController extends UpdateController {
  _MockUpdateController()
    : super(
        checkForUpdate: CheckForUpdate(_FakeUpdateRepo()),
        downloadUpdate: DownloadUpdate(_FakeUpdateRepo()),
        installUpdate: InstallUpdate(_FakeUpdateRepo()),
      );

  @override
  UpdateState build() => const UpdateIdle();
}

class _FakeDesktopNotifier extends DesktopNotifier {
  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool?> permissionGranted() async => true;
}

class _FakeZenTaoProfileStartupController
    implements ZenTaoProfileStartupController {
  @override
  void onAccountsLoaded(List<Account> accounts) {}
}

class _SavedNavController extends AppNavController {
  _SavedNavController(this._saved);
  final AppNavState _saved;

  @override
  AppNavState build() => _saved;
}

Widget _buildApp({AppNavState? initialNav}) {
  return ProviderScope(
    overrides: [
      toolRegistryProvider.overrideWithValue(defaultToolRegistry),
      updateControllerProvider.overrideWith(_MockUpdateController.new),
      notificationAccountsProvider.overrideWith((ref) => const []),
      chatAutoConnectProvider.overrideWith((ref) {}),
      zenTaoProfileStartupControllerProvider.overrideWith(
        (ref) => _FakeZenTaoProfileStartupController(),
      ),
      desktopNotifierProvider.overrideWith((ref) => _FakeDesktopNotifier()),
      if (initialNav != null)
        appNavProvider.overrideWith(() => _SavedNavController(initialNav)),
    ],
    child: const WorkNexusApp(),
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await getIt.reset();
    await db.close().timeout(
      const Duration(milliseconds: 300),
      onTimeout: () {},
    );
  });

  testWidgets(
    'Integration flow: launch -> first app & feature -> select workspace -> overview -> state restore',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Launch → lands on the first active account and its first feature
      await tester.pumpWidget(_buildApp());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TitleBar), findsOneWidget);
      expect(find.byType(AppNavRail), findsOneWidget);
      expect(find.byType(WorkspaceNavPane), findsNothing);
      expect(find.byType(Viewport), findsOneWidget);

      final element = tester.element(find.byType(WorkNexusApp));
      final container = ProviderScope.containerOf(element);
      final navState = container.read(appNavProvider);
      expect(navState.rail, isA<AccountTarget>());
      expect((navState.rail as AccountTarget).accountId, 'ghP');
      expect(navState.locations['ghP']?.section.value, 'github.pulls');

      // 2. Tap workspace button on the rail → nav pane switches to workspace
      final workspaceButton = find.byType(RailWorkspaceButton);
      expect(workspaceButton, findsOneWidget);

      await tester.tap(workspaceButton);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(WorkspaceNavPane), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Assigned to you'), findsOneWidget);

      // 3. Capture navigation state
      final savedState = container.read(appNavProvider);
      expect(savedState.rail, isA<WorkspaceTarget>());
      expect(savedState.userSelectedWorkspace, isTrue);

      // 4. Re-pump with saved state → workspace view restores
      await disposeTree(tester);
      await tester.pumpWidget(_buildApp(initialNav: savedState));
      await tester.pump(const Duration(milliseconds: 600));

      // The workspace nav pane should appear (workspace is selected)
      expect(find.byType(WorkspaceNavPane), findsOneWidget);
      expect(find.byType(AppNavRail), findsOneWidget);
      expect(find.byType(Viewport), findsOneWidget);

      await disposeTree(tester);
    },
  );

  testWidgets('Workspace Overview shows tool cards when workspace selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 600));

    // Tap workspace button to see Workspace Overview
    final workspaceButton = find.byType(RailWorkspaceButton);
    expect(workspaceButton, findsOneWidget);
    await tester.tap(workspaceButton);
    await tester.pump(const Duration(milliseconds: 600));

    // Default workspace is Personal with GitHub account 'ghP'
    expect(find.text('GitHub'), findsWidgets);
    expect(find.text('Overview'), findsWidgets);

    await disposeTree(tester);
  });

  testWidgets('Switching workspace via provider updates the Overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 600));

    // Switch to compB which has ZenTao, GitHub, and GitLab
    final element = tester.element(find.byType(WorkNexusApp));
    final container = ProviderScope.containerOf(element);
    container.read(activeWorkspaceIdProvider.notifier).state = 'compB';
    // Also reset to workspace Overview
    container
        .read(appNavProvider.notifier)
        .selectWorkspaceSection(WorkspaceSection.overview);
    await tester.pump(const Duration(milliseconds: 600));

    // compB has ZenTao, GitLab, and GitHub accounts
    expect(find.text('ZenTao'), findsWidgets);
    expect(find.text('GitLab'), findsWidgets);

    await disposeTree(tester);
  });
}
