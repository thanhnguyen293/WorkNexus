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
import 'package:work_nexus/tools/zentao/presentation/nav/zentao_projects_scope_list.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';

void main() {
  const account = Account(
    id: 'acc-zt',
    workspaceId: 'ws-1',
    providerType: ProviderType.zentao,
    handle: 'dev_zt',
    baseUrl: 'https://zentao.corp.net',
  );

  const testLocation = ToolLocation(section: SectionId('zentao.tasks'));

  testWidgets('Pinned child executions appear in PINNED section', (
    tester,
  ) async {
    const pinnedExec = PinnedExecution(
      accountId: 'acc-zt',
      projectId: 'proj-1',
      executionId: 'exec-99',
      name: 'VN_Daily_Tasks',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zentaoProjectsProvider(
            'acc-zt',
          ).overrideWith((ref) => Stream.value(const <ProviderProject>[])),
          ticketsProvider.overrideWith((ref) => Stream.value(const <Ticket>[])),
          appSettingsProvider.overrideWith(
            () => _TestSettingsController(
              const AppSettings(pinnedExecutions: [pinnedExec]),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: ZentaoProjectsScopeList(
                account: account,
                location: testLocation,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify VN_Daily_Tasks appears in the Pinned section
    expect(find.text('VN_Daily_Tasks'), findsOneWidget);
    expect(find.text('PINNED'), findsOneWidget);
  });
}

class _TestSettingsController extends AppSettingsController {
  _TestSettingsController(this._initial);
  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}
