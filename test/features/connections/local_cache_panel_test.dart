import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/domain/entities/cache_section.dart';
import 'package:work_nexus/features/connections/domain/repositories/local_cache_repository.dart';
import 'package:work_nexus/features/connections/domain/usecases/clear_local_cache.dart';
import 'package:work_nexus/features/connections/presentation/providers/local_cache_providers.dart';
import 'package:work_nexus/features/connections/presentation/widgets/local_cache_panel.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockRepository extends Mock implements LocalCacheRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<CacheSection>{}));

  testWidgets('every section starts picked; only the picked ones clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MockRepository();
    when(() => repository.clear(any())).thenAnswer((_) async => const Ok(null));
    Set<CacheSection>? cleared;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clearLocalCacheProvider.overrideWithValue(
            ClearLocalCache(repository),
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
          home: Scaffold(body: LocalCachePanel(onCleared: (s) => cleared = s)),
        ),
      ),
    );

    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((t) => t.value ?? false),
      isTrue,
    );

    await tester.tap(find.text('Chat'));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    const expected = {
      CacheSection.tickets,
      CacheSection.dashboard,
      CacheSection.translations,
    };
    verify(() => repository.clear(expected)).called(1);
    expect(cleared, expected);
    expect(find.text('Cache cleared, downloading again…'), findsOneWidget);
  });
}
