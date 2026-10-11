import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/open_storage.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/quick_settings_side_panel.dart';
import 'package:work_nexus/features/connections/presentation/widgets/local_cache_quick_settings.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('Quick Settings opens the storage dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    final container = ProviderContainer(
      overrides: [openStorageProvider.overrideWithValue((_) => opened++)],
    );
    addTearDown(container.dispose);
    container.read(mainViewProvider.notifier).state = MainView.board;
    container.read(quickSettingsOpenProvider.notifier).state = true;

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
            body: QuickSettingsSidePanel(
              generalSections: [LocalCacheQuickSettings()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Manage storage…'), 200);
    await tester.tap(find.text('Manage storage…'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });
}
