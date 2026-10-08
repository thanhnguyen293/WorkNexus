import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_button.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';
import 'package:work_nexus/features/board/presentation/widgets/saved_filters_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

/// The popover's saved-filter block: save the filter on screen under a name,
/// apply it later, delete it. Backed by drift, so this exercises the whole
/// path — controller → use case → repository → DB → stream.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator(seed: false));
  tearDown(() async => resetTestLocator(db));

  Future<ProviderContainer> pumpSection(WidgetTester tester) async {
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
            body: SingleChildScrollView(child: SavedFiltersSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> savePreset(WidgetTester tester, String name) async {
    await tester.tap(find.textContaining('Save current filter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    // The Save action stays disabled until the field rebuilds with a name.
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: 'dialog should close');
  }

  testWidgets('with no presets it explains how to make one', (tester) async {
    await pumpSection(tester);

    expect(
      find.text('No presets yet — set up a filter, then save it.'),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('saving the current filter adds a preset chip', (tester) async {
    final container = await pumpSection(tester);
    container
        .read(filterStateProvider.notifier)
        .toggleStatus(UnifiedStatus.blocked);
    await tester.pumpAndSettle();

    await savePreset(tester, 'Blocked work');

    expect(find.text('Blocked work'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('tapping a preset puts its criteria back on the board', (
    tester,
  ) async {
    final container = await pumpSection(tester);
    final filters = container.read(filterStateProvider.notifier);
    filters.toggleStatus(UnifiedStatus.blocked);
    await tester.pumpAndSettle();

    await savePreset(tester, 'Blocked work');

    filters.clearAll();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blocked work'));
    await tester.pumpAndSettle();

    expect(container.read(filterStateProvider).statuses, {
      UnifiedStatus.blocked,
    });
    await disposeTree(tester);
  });
}
