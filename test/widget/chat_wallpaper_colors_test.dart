import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/hsv_color_fields.dart';
import 'package:work_nexus/core/widgets/swatch_button.dart';
import 'package:work_nexus/features/chat/presentation/providers/wallpaper_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_wallpaper_colors.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

/// Picking a wallpaper colour, then turning the pattern over it off.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
            body: SingleChildScrollView(
              child: SizedBox(width: 360, child: ChatWallpaperColors()),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('a free colour is picked in place; the background follows', (
    tester,
  ) async {
    final container = await pump(tester);
    String saved() => container.read(appSettingsProvider).chatWallpaper;
    String shown() => container.read(shownChatWallpaperProvider);
    final before = saved();

    // The last swatch opens the picker under the swatches, not a dialog.
    await tester.tap(find.byType(SwatchButton).last);
    await tester.pump();
    expect(find.byType(HsvHueBar), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(HsvSaturationValueArea)));
    await tester.pump();
    // On screen at once; saved only once the picking rests.
    expect(shown(), startsWith('tint:#'));
    expect(saved(), before);

    await tester.pump(const Duration(milliseconds: 500));
    expect(saved(), shown());
    expect(container.read(chatWallpaperPreviewProvider), isNull);
  });

  testWidgets('a colour starts with the pattern, which can be turned off', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
            body: SizedBox(width: 360, child: ChatWallpaperColors()),
          ),
        ),
      ),
    );
    String wallpaper() => container.read(appSettingsProvider).chatWallpaper;

    // The default wallpaper is green with the pattern.
    expect(find.text('Pattern over the colour'), findsOneWidget);

    // After the app's own background and green, blue.
    await tester.tap(find.byType(SwatchButton).at(2));
    await tester.pump();
    expect(wallpaper(), 'tint:blue');

    await tester.tap(find.text('Pattern over the colour'));
    await tester.pump();
    expect(wallpaper(), 'solid:blue');

    // Another colour keeps the pattern off.
    await tester.tap(find.byType(SwatchButton).at(3));
    await tester.pump();
    expect(wallpaper(), 'solid:teal');

    // The app's own background: plain, no pattern to switch.
    await tester.tap(find.byType(SwatchButton).first);
    await tester.pump();
    expect(wallpaper(), 'none');
    expect(find.text('Pattern over the colour'), findsNothing);
  });
}
