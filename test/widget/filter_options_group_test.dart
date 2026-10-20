import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_chip.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_option_group.dart';

/// [FilterOptionsGroup] stays a wrap of chips while it is short, and becomes a
/// dropdown — a field naming what is picked that opens into a searchable
/// checklist — once it is long. A search never hides an option that is
/// already picked (which would strand an active filter).
void main() {
  List<String> names(int count) => [for (var i = 0; i < count; i++) 'user-$i'];

  Future<List<String>> pumpGroup(
    WidgetTester tester, {
    required List<String> options,
    Set<String> active = const {},
  }) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FilterOptionsGroup(
              label: 'Assignee',
              options: [
                for (final o in options)
                  FilterChipOption(
                    label: o,
                    active: active.contains(o),
                    onTap: () => tapped.add(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tapped;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byIcon(LucideIcons.chevronDown300));
    await tester.pumpAndSettle();
  }

  testWidgets('a short group stays a wrap of chips', (tester) async {
    await pumpGroup(tester, options: names(3));

    expect(find.text('ASSIGNEE'), findsOneWidget);
    expect(find.byType(FilterOptionChip), findsNWidgets(3));
    expect(find.text('Any'), findsNothing);
  });

  testWidgets('a long group is a closed dropdown saying nothing is picked', (
    tester,
  ) async {
    await pumpGroup(tester, options: names(20));

    expect(find.text('Any'), findsOneWidget);
    expect(find.byType(FilterOptionChip), findsNothing);
    expect(find.text('user-7'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the closed dropdown names what is picked', (tester) async {
    await pumpGroup(tester, options: names(20), active: {'user-2', 'user-5'});

    expect(find.text('user-2, user-5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('opening it lists the options with a search box', (tester) async {
    await pumpGroup(tester, options: names(20));
    await open(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('user-7'), findsOneWidget);
  });

  testWidgets('tapping an option toggles it', (tester) async {
    final tapped = await pumpGroup(tester, options: names(20));
    await open(tester);

    await tester.tap(find.text('user-3'));

    expect(tapped, ['user-3']);
  });

  testWidgets('typing narrows the list to the matches', (tester) async {
    await pumpGroup(tester, options: names(20));
    await open(tester);

    await tester.enterText(find.byType(TextField), '-13');
    await tester.pumpAndSettle();

    expect(find.text('user-13'), findsOneWidget);
    expect(find.text('user-7'), findsNothing);
  });

  testWidgets('a picked option stays listed through a search', (tester) async {
    await pumpGroup(tester, options: names(20), active: {'user-2'});
    await open(tester);

    await tester.enterText(find.byType(TextField), '-13');
    await tester.pumpAndSettle();

    expect(find.text('user-13'), findsOneWidget);
    // The closed field's summary and the row in the list.
    expect(find.text('user-2'), findsNWidgets(2));
  });

  testWidgets('a query matching nothing says so', (tester) async {
    await pumpGroup(tester, options: names(20));
    await open(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No option matches'), findsOneWidget);
  });
}
