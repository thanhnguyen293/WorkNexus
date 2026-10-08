import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/board/presentation/board_refresh.dart';
import 'package:work_nexus/features/board/presentation/filter_providers.dart';
import 'package:work_nexus/features/board/presentation/widgets/chrome_bar.dart';
import 'package:work_nexus/features/board/presentation/widgets/sidebar_primitives.dart';
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

  Future<void> pump(WidgetTester tester, {bool refreshing = false}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (refreshing) boardRefreshingProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(body: ChromeBar()),
        ),
      ),
    );
  }

  testWidgets('the toolbar offers a refresh action', (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byIcon(PhosphorIconsLight.arrowClockwise), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(PhosphorIconsLight.arrowClockwise));
    await tester.pump();

    // Nothing is selected, so the refresh is a no-op rather than an error.
    expect(tester.takeException(), isNull);

    await disposeTree(tester);
  });

  testWidgets('a board fetch in flight replaces the icon with a spinner', (
    tester,
  ) async {
    await pump(tester, refreshing: true);
    await tester.pump();

    expect(find.byIcon(PhosphorIconsLight.arrowClockwise), findsNothing);
    expect(find.byType(SidebarSyncIndicator), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('a narrow toolbar with filter chips does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChromeBar)),
    );
    container.read(filterStateProvider.notifier)
      ..toggleAssignee('Thanh')
      ..toggleAssignee('Someone with a long name');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Thanh'), findsOneWidget);

    await disposeTree(tester);
  });
}
