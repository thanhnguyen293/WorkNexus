import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/features/translation/presentation/widgets/translation_settings_card.dart';
import 'package:work_nexus/features/translation/domain/entities/translation_api_config.dart';
import 'package:work_nexus/features/translation/presentation/translation_api_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('one card summarises the setup and expands to its settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeModelsProvider.overrideWith((ref) async => const <String>[]),
          translationApiModelsProvider.overrideWith(
            (ref, query) async => const Ok(['m', 'm-2']),
          ),
          translationApiConfigProvider.overrideWith(
            (ref) async => const Ok(
              TranslationApiConfig(
                presetId: 'gemini',
                baseUrl: 'https://example.test',
                model: 'm',
                apiKey: 'k',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.flat,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: TranslationSettingsCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Google Gemini'), findsOneWidget);
    expect(find.text('Translation provider'), findsNothing);

    await tester.tap(find.text('Translation'));
    await tester.pumpAndSettle();

    // One provider section: the saved Gemini key, with Gemini's own models.
    expect(find.text('Translation provider'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);
  });
}
