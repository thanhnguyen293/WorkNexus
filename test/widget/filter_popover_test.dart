import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_popover_anchor.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filters_button.dart';

import '../support/di_test_harness.dart';

const _outside = Key('outside');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await resetTestLocator(db);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filterHasGroupsProvider.overrideWithValue(true)],
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
          home: Scaffold(
            body: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FiltersButton(enabled: enabled),
                ),
                const Expanded(child: SizedBox.expand(key: _outside)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(FiltersButton)),
    );
  }

  Finder clearAll() => find.text('Clear all');

  testWidgets('a click outside the popover closes it', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.byIcon(LucideIcons.funnel300));
    await tester.pumpAndSettle();
    expect(clearAll(), findsOneWidget);

    await tester.tapAt(
      tester.getBottomRight(find.byKey(_outside)) - const Offset(20, 20),
    );
    await tester.pumpAndSettle();
    expect(clearAll(), findsNothing);
    expect(container.read(advFilterOpenProvider), isFalse);

    await disposeTree(tester);
  });

  testWidgets('a disabled Filters button opens nothing', (tester) async {
    final container = await pump(tester, enabled: false);

    await tester.tap(find.byIcon(LucideIcons.funnel300));
    await tester.pumpAndSettle();

    expect(clearAll(), findsNothing);
    expect(container.read(advFilterOpenProvider), isFalse);

    await disposeTree(tester);
  });

  testWidgets('disabling the Filters button closes its popover', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(advFilterOpenProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(clearAll(), findsOneWidget);

    await pump(tester, enabled: false);
    await tester.pumpAndSettle();

    expect(container.read(advFilterOpenProvider), isFalse);

    await disposeTree(tester);
  });

  testWidgets('the Filters button toggles the popover', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(LucideIcons.funnel300));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.funnel300));
    await tester.pumpAndSettle();

    expect(clearAll(), findsNothing);

    await disposeTree(tester);
  });

  testWidgets('Clear all resets the filter', (tester) async {
    final container = await pump(tester);
    container.read(filterStateProvider.notifier).setSearch('report');
    container.read(advFilterOpenProvider.notifier).state = true;
    await tester.pumpAndSettle();

    await tester.tap(clearAll());
    await tester.pumpAndSettle();

    expect(container.read(filterStateProvider).search, isEmpty);

    await disposeTree(tester);
  });
}
