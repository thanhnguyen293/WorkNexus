import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/quick_settings_side_panel.dart';
import 'package:work_nexus/features/connections/domain/entities/cache_section.dart';
import 'package:work_nexus/features/connections/domain/repositories/local_cache_repository.dart';
import 'package:work_nexus/features/connections/domain/usecases/clear_local_cache.dart';
import 'package:work_nexus/features/connections/presentation/providers/local_cache_providers.dart';
import 'package:work_nexus/features/connections/presentation/widgets/local_cache_quick_settings.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockRepository extends Mock implements LocalCacheRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<CacheSection>{}));

  testWidgets('Quick Settings clears the cache and reports what went', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MockRepository();
    when(() => repository.clear(any())).thenAnswer((_) async => const Ok(null));
    final container = ProviderContainer(
      overrides: [
        clearLocalCacheProvider.overrideWithValue(ClearLocalCache(repository)),
      ],
    );
    addTearDown(container.dispose);
    container.read(mainViewProvider.notifier).state = MainView.board;
    container.read(quickSettingsOpenProvider.notifier).state = true;
    Set<CacheSection>? cleared;

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
          home: Scaffold(
            body: QuickSettingsSidePanel(
              generalSections: [
                LocalCacheQuickSettings(onCleared: (s) => cleared = s),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Clear cache…'), 200);
    await tester.tap(find.text('Clear cache…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(cleared, {...CacheSection.values});
    verify(() => repository.clear({...CacheSection.values})).called(1);
    expect(find.text('Cache cleared, downloading again…'), findsOneWidget);
  });
}
