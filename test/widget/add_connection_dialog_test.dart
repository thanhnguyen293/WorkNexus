import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/presentation/add_connection_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await resetTestLocator(db);
  });

  testWidgets(
    'AddConnectionDialog opens without modifying a provider in build',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildAppTheme(
              variant: AppThemeVariant.light,
              surface: SurfaceStyle.outline,
              density: AppDensity.comfortable,
            ),
            home: const Scaffold(body: AddConnectionDialog()),
          ),
        ),
      );
      // Runs the post-frame reset() that previously threw.
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Connect ZenTao'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);

      await disposeTree(tester);
    },
  );
}
