import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/domain/value_objects/saved_view.dart';
import 'package:work_nexus/shared/board/presentation/providers/filter_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/sections/zentao_tasks_section.dart';

const _testAccount = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'tester',
);

void main() {
  test(
    'FilterController defaults to SavedView.mine for zentao.tasks and zentao.bugs',
    () {
      final container = ProviderContainer(
        overrides: [
          appNavProvider.overrideWith(() => _TestNavNotifier('zentao.tasks')),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(filterStateProvider).savedView, SavedView.mine);

      // Switch to zentao.bugs
      container.read(filterStateProvider.notifier).openBoard('zentao.bugs');
      expect(container.read(filterStateProvider).savedView, SavedView.mine);
    },
  );

  testWidgets('ZentaoTasksSection defaults to Assigned to me selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const initialNav = AppNavState(
      rail: RailTarget.account('acc-zt'),
      locations: {'acc-zt': ToolLocation(section: SectionId('zentao.tasks'))},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appNavProvider.overrideWith(
            () => _TestNavNotifier('zentao.tasks', initialNav),
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
          home: const Scaffold(
            body: ZentaoTasksSection(
              account: _testAccount,
              location: ToolLocation(section: SectionId('zentao.tasks')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Assigned to me" and "All tasks" exist
    expect(find.text('Assigned to me'), findsOneWidget);
    expect(find.text('All tasks'), findsOneWidget);
  });
}

class _TestNavNotifier extends AppNavController {
  _TestNavNotifier(this.sectionKey, [this.initialState]);

  final String sectionKey;
  final AppNavState? initialState;

  @override
  AppNavState build() =>
      initialState ??
      AppNavState(
        rail: const RailTarget.account('acc-zt'),
        locations: {'acc-zt': ToolLocation(section: SectionId(sectionKey))},
      );
}
