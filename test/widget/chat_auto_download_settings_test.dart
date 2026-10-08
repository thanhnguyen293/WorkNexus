import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_auto_download_settings.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  testWidgets('videos auto-download up to 20 MB; both can be changed', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SizedBox(width: 360, child: ChatAutoDownloadSettings()),
          ),
        ),
      ),
    );
    AppSettings settings() => container.read(appSettingsProvider);
    expect(settings().chatAutoDownloadVideos, isTrue);
    expect(settings().chatAutoDownloadVideoMb, 20);

    await tester.tap(find.text('50 MB'));
    await tester.pump();
    expect(settings().chatAutoDownloadVideoMb, 50);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(settings().chatAutoDownloadVideos, isFalse);
    expect(find.text('50 MB'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
