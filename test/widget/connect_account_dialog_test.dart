import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/connections/presentation/connect_account_dialog.dart';
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

  testWidgets('picks the provider inside the connect dialog', (tester) async {
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
          home: const Scaffold(body: ConnectAccountDialog()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // ZenTao's form first, under every provider.
    expect(find.text('Connect ZenTao'), findsOneWidget);
    expect(find.text('Account (username)'), findsOneWidget);
    for (final name in ['GitHub', 'GitLab', 'Jira', 'ZenTao']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('GitHub'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Connect GitHub'), findsOneWidget);
    expect(find.text('Personal Access Token'), findsOneWidget);
    expect(find.text('Account (username)'), findsNothing);

    // Jira is not supported yet: picking it changes nothing.
    await tester.tap(find.text('Jira'));
    await tester.pump();
    expect(find.text('Connect GitHub'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
