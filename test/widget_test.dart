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
import 'package:work_nexus/core/database/database_seeder.dart';
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

import 'support/di_test_harness.dart';

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

Widget _buildTestApp() {
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
    'App boots into first app and its first feature when accounts exist',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
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

      await disposeTree(tester);
    },
  );

  testWidgets(
    'First launch without accounts opens Workspace Overview empty state',
    (tester) async {
      await purgeSeededDemoData(db);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('No tools connected yet'), findsOneWidget);
      expect(find.text('Connect a tool'), findsWidgets);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'Unified workspace shell navigation flow: default app to Workspace Overview',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump(const Duration(milliseconds: 600));

      // Initially on first app's view
      expect(find.byType(WorkspaceNavPane), findsNothing);

      // Tap on the Workspace button on the rail
      final workspaceButton = find.byType(RailWorkspaceButton);
      expect(workspaceButton, findsOneWidget);
      await tester.tap(workspaceButton);
      await tester.pump(const Duration(milliseconds: 600));

      // WorkspaceNavPane should now appear
      expect(find.byType(WorkspaceNavPane), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);

      await disposeTree(tester);
    },
  );
}
