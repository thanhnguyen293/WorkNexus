import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/app_nav_rail.dart';
import 'package:work_nexus/app/shell/rail_account_button.dart';
import 'package:work_nexus/app/shell/rail_connect_button.dart';
import 'package:work_nexus/app/shell/rail_workspace_button.dart';
import 'package:work_nexus/app/tool_registry.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/tools/tool_registry_provider.dart';
import 'package:work_nexus/core/widgets/unread_badge.dart';
import 'package:work_nexus/features/app_update/domain/entities/available_update.dart';
import 'package:work_nexus/features/app_update/domain/repositories/update_repository.dart';
import 'package:work_nexus/features/app_update/domain/usecases/check_for_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/download_update.dart';
import 'package:work_nexus/features/app_update/domain/usecases/install_update.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_controller.dart';
import 'package:work_nexus/features/app_update/presentation/providers/update_state.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/connections/presentation/connect_account_dialog.dart';
import 'package:work_nexus/features/notifications/presentation/providers/notification_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/mini_app_overrides.dart';

const _testWorkspace = Workspace(
  id: 'ws-1',
  name: 'Default Workspace',
  shortCode: 'DW',
  colorValue: 0xFF1D9BF0,
);

const _accountZt = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'alice',
  baseUrl: 'https://zentao.example.com',
);

const _accountGl1 = Account(
  id: 'acc-gl-1',
  workspaceId: 'ws-1',
  providerType: ProviderType.gitlab,
  handle: 'gitlab-work',
  baseUrl: 'https://gitlab.com',
);

const _accountGl2 = Account(
  id: 'acc-gl-2',
  workspaceId: 'ws-1',
  providerType: ProviderType.gitlab,
  handle: 'gitlab-personal',
  baseUrl: 'https://gitlab.com',
);

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

Widget _buildTestApp({
  required Widget child,
  List<Account> accounts = const [_accountZt, _accountGl1, _accountGl2],
  int unreadCount = 0,
  AppNavState? initialNav,
}) {
  return ProviderScope(
    overrides: [
      ...miniAppShellOverrides(),
      toolRegistryProvider.overrideWithValue(defaultToolRegistry),
      activeWorkspaceProvider.overrideWithValue(_testWorkspace),
      activeWorkspaceIdProvider.overrideWith((ref) => 'ws-1'),
      accountsProvider.overrideWith((ref) => Stream.value(accounts)),
      chatUnreadTotalProvider.overrideWith((ref) => unreadCount),
      updateControllerProvider.overrideWith(_MockUpdateController.new),
      notificationAccountsProvider.overrideWith((ref) => const []),
      if (initialNav != null)
        appNavProvider.overrideWith(() => _TestNavController(initialNav)),
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

class _TestNavController extends AppNavController {
  _TestNavController([this._initial]);
  final AppNavState? _initial;

  @override
  AppNavState build() => _initial ?? super.build();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppNavRail', () {
    testWidgets('shows workspace button and account buttons in order', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const AppNavRail()));
      await tester.pumpAndSettle();

      expect(find.byType(RailWorkspaceButton), findsOneWidget);
      expect(find.byType(RailAccountButton), findsNWidgets(3));
      expect(find.byType(RailConnectButton), findsOneWidget);
    });

    testWidgets(
      'two GitLab accounts show both handles instead of provider name',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(child: const AppNavRail()));
        await tester.pumpAndSettle();

        // ZenTao is unique, so it shows provider name
        expect(find.text('ZenTao'), findsOneWidget);

        // Two GitLab accounts repeat the provider, so they show their handles
        expect(find.text('gitlab-work'), findsOneWidget);
        expect(find.text('gitlab-personal'), findsOneWidget);
        expect(find.text('GitLab'), findsNothing);
      },
    );

    testWidgets('ZenTao account shows unread badge when unreadCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: const AppNavRail(), unreadCount: 5),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnreadBadge), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('clicking an account button calls selectAccount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const AppNavRail(),
          initialNav: const AppNavState(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavRail)),
      );
      expect(container.read(appNavProvider).rail, const WorkspaceTarget());

      // Tap ZenTao account
      await tester.tap(find.text('ZenTao'));
      await tester.pumpAndSettle();

      expect(
        container.read(appNavProvider).rail,
        const AccountTarget('acc-zt'),
      );
    });

    testWidgets('+ Connect opens ConnectAccountDialog', (tester) async {
      await tester.pumpWidget(_buildTestApp(child: const AppNavRail()));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectAccountDialog), findsNothing);

      await tester.tap(find.byType(RailConnectButton));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectAccountDialog), findsOneWidget);
    });

    testWidgets(
      'Ctrl/Cmd+1 selects Workspace, Ctrl/Cmd+2 selects first account',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: const AppNavRail(),
            initialNav: const AppNavState(rail: AccountTarget('acc-gl-1')),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AppNavRail)),
        );
        expect(
          container.read(appNavProvider).rail,
          const AccountTarget('acc-gl-1'),
        );

        // Press Ctrl+1
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pumpAndSettle();

        expect(container.read(appNavProvider).rail, const WorkspaceTarget());

        // Press Ctrl+2 (selects 1st sorted account: acc-zt)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pumpAndSettle();

        expect(
          container.read(appNavProvider).rail,
          const AccountTarget('acc-zt'),
        );
      },
    );
  });
}
